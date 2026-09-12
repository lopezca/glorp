Class {
	#name : #GlorpDatabasePlatformTest,
	#superclass : #GlorpTestCase,
	#category : #'Glorp-Unit-Tests-Tests'
}

{ #category : #utilities }
GlorpDatabasePlatformTest >> addToString: aString [
	"Append a couple of special characters. The result will utf-8 encode to be 3 characters longer than its number of characters"
	^aString, (String with: (Character value: 16r2022) "bullet point" with: (Character value: 16r0131) "Turkish i with no dot")

"If PostgreSQL, or another DB returning true to measuresStringFieldWidthsInBytes, is provided in VA, this test must alter to
handle incompatible protocol between VW, which lacks Character>>asString and VA, in which String>>with:with: will not handle
double-byte entries.  The VA could be implemented as
	^aString, (Character value: 16r2022) asString, (Character value: 16r0131) asString
"
]

{ #category : #utilities }
GlorpDatabasePlatformTest >> helpTestPrintTimestamp: aTimestampString [

	| aStream ts timestamp |
	ts := DatabasePlatform new readTimestamp: aTimestampString for: nil.
	aStream := WriteStream on: String new.
	DatabasePlatform new printDate: ts isoFormatOn: aStream.
	aStream nextPut: Character space.
	DatabasePlatform new
		printTime: ts
		isoFormatOn: aStream
		milliseconds: Dialect supportsMillisecondsInTimes.
	timestamp := aStream contents.
	self assert: timestamp equals: aTimestampString
]

{ #category : #utilities }
GlorpDatabasePlatformTest >> string20 [

	| platform |
	platform := PostgresPlatform new.
	platform characterEncoding: #'utf-8'.
	^ platform varchar: 20
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testNumericCoercion [

	| type platform num |
	type := GlorpNumericType new scale: 5; precision: 2.
	platform := DatabasePlatform new.
	num := Dialect coerceToDoublePrecisionFloat: (123456 / 100).
	self assert: (platform convertToNumber: num for: type) equals: num.
	num := Dialect coerceToDoublePrecisionFloat: (123450 / 100).
	self assert: (platform convertToNumber: num for: type) equals: num.
	num := Dialect coerceToDoublePrecisionFloat: (123450 / 1000).
	self assert: (platform convertToNumber: num for: type) equals: num.
	num := Dialect coerceToDoublePrecisionFloat: (123456 / 1000).
	self deny: (platform convertToNumber: num for: type) equals: num
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testPrintDateIsoFormat [
	"Dates print in ISO 8601 extended format; years outside 0000 to 9999 use a sign and at least 4 digits"

	| platform |
	platform := DatabasePlatform new.
	{ (Date year: 2024 month: 3 day: 5) -> '2024-03-05'.
	  (Date year: 9999 month: 12 day: 31) -> '9999-12-31'.
	  (Date year: 5 month: 1 day: 2) -> '0005-01-02'.
	  (Date year: 0 month: 1 day: 1) -> '0000-01-01'.
	  (Date year: -43 month: 3 day: 15) -> '-0043-03-15'.
	  (Date year: 12024 month: 1 day: 1) -> '+12024-01-01'.
	  (Date year: -12024 month: 1 day: 1) -> '-12024-01-01' } do: [ :each | | stream |
		stream := WriteStream on: String new.
		platform printDate: each key isoFormatOn: stream.
		self assert: stream contents equals: each value ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testPrintDatePostgreSQLFormat [
	"PostgreSQL rejects signed years: it prints and reads years before 1 CE with a BC suffix (it has no year 0, so astronomical year 0 is 0001 BC), and years after 9999 unsigned"

	| platform |
	platform := PostgreSQLPlatform new.
	{ (Date year: 2024 month: 3 day: 5) -> '2024-03-05'.
	  (Date year: 5 month: 1 day: 2) -> '0005-01-02'.
	  (Date year: 9999 month: 12 day: 31) -> '9999-12-31'.
	  (Date year: 12024 month: 1 day: 1) -> '12024-01-01'.
	  (Date year: 0 month: 1 day: 1) -> '0001-01-01 BC'.
	  (Date year: -43 month: 3 day: 15) -> '0044-03-15 BC' } do: [ :each | | stream |
		stream := WriteStream on: String new.
		platform printDate: each key isoFormatOn: stream.
		self assert: stream contents equals: each value ].
	self
		assert: (platform printDate: (Date year: -43 month: 3 day: 15) for: nil)
		equals: '''0044-03-15 BC'''
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testPrintTimestamp [

	| strings |
	strings := #( '2005-01-01 21:29:28.337'  '2005-01-01 01:02:00.037'  '2005-01-01 21:29:28.002'  '2005-01-01 21:29:28.001').
	strings do: [:each |
		self helpTestPrintTimestamp: each]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateAndToDateFromString [
	"Strings are parsed as ISO 8601 in both directions, without going through the deprecated String>>#asDate"

	| platform |
	platform := DatabasePlatform new.
	self
		assert: (platform toDate: '2024-03-15' for: nil)
		equals: (Date year: 2024 month: 3 day: 15).
	self
		assert: (platform readDate: '2024-03-15' for: nil)
		equals: (Date year: 2024 month: 3 day: 15).
	self should: [ platform toDate: '2024/03/15' for: nil ] raise: Error.
	self should: [ platform readDate: '2024/03/15' for: nil ] raise: Error.
	self
		shouldnt: [ platform toDate: '2024-03-15' for: nil ]
		raise: Deprecation
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStream [

	| platform |
	platform := DatabasePlatform new.
	self
		assert: (platform readDateFromStream: '2024-03-15' readStream for: nil)
		equals: (Date year: 2024 month: 3 day: 15).
	self
		assert: (platform readDateFromStream: '0987-01-02' readStream for: nil)
		equals: (Date year: 987 month: 1 day: 2)
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamErrorMessages [
	"Parsing errors name the offending input"

	#('15/03/24' '2024-03/15' '2024-003-15' '2024-03-015' '2024') do: [ :each |
		self
			should: [ DatabasePlatform new readDateFromStream: each readStream for: nil ]
			raise: Error
			withExceptionDo: [ :error | self assert: (error messageText includesSubstring: each) ] ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamIgnoresTime [
	"A time part starting with $T or a space is left unread"

	| platform |
	platform := DatabasePlatform new.
	#('2024-03-15 23:30:00-06' '2024-03-15T23:30:00' '2024-03-15 00:00:00.123' '2024-03-15T') do: [ :each |
		self
			assert: (platform readDateFromStream: each readStream for: nil)
			equals: (Date year: 2024 month: 3 day: 15) ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamInvalid [

	| platform |
	platform := DatabasePlatform new.
	#('' '2024' '2024-03' '2024-03-' '03/15/2024' '20240315' 'abcd-ef-gh') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamInvalidSignedYears [
	"A sign must be followed by at least 4 digits"

	| platform |
	platform := DatabasePlatform new.
	#('-' '+' '-/03/15' '+-03-15' '--2024-03-15' '+-2024-03-15' '-43-03-15' '-1-12-31' '+0-01-01' '+123-01-01') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamLeavesStreamAfterDay [
	"Only the date is consumed, the stream is left at whatever follows the day"

	| stream |
	stream := '2024-03-15 23:30:00' readStream.
	self
		assert: (DatabasePlatform new readDateFromStream: stream for: nil)
		equals: (Date year: 2024 month: 3 day: 15).
	self assert: stream upToEnd equals: ' 23:30:00'
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamLongYears [
	"Years beyond 4 digits need a sign"

	| platform |
	platform := DatabasePlatform new.
	{ '+12024-03-15' -> (Date year: 12024 month: 3 day: 15).
	  '-12024-03-15' -> (Date year: -12024 month: 3 day: 15) } do: [ :each |
		self
			assert: (platform readDateFromStream: each key readStream for: nil)
			equals: each value ].
	self
		should: [ platform readDateFromStream: '12024-03-15' readStream for: nil ]
		raise: Error
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamMismatchedSeparators [

	| platform |
	platform := DatabasePlatform new.
	#('2024-03/15' '2024/03-15') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamMonthAndDayDigits [
	"Month and day have exactly 2 digits"

	| platform |
	platform := DatabasePlatform new.
	#('2024-3-15' '2024-03-5' '2024-3-5' '0987-3-7' '2024-003-15' '2024-03-015' '2024--15' '2024-03-' '2024-3-') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamRequiresHyphens [
	"The extended format separates year, month and day with hyphens only"

	| platform emDash |
	platform := DatabasePlatform new.
	emDash := String with: (Character value: 16r2014).
	{ '2024/03/15'. '2024.03.15'. '2024 03 15'. '2024-03/15'. '2024/03-15'. '2024' , emDash , '03' , emDash , '15' } do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamRequiresYearPadding [
	"Year must be zero-padded to 4 digits"

	| platform |
	platform := DatabasePlatform new.
	#('987-01-02') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamRespectsReadLimit [
	"Characters beyond the stream's read limit are not read"

	| platform |
	platform := DatabasePlatform new.
	self
		assert: (platform readDateFromStream: (ReadStream on: '2024-03-1599' from: 1 to: 10) for: nil)
		equals: (Date year: 2024 month: 3 day: 15).
	self
		should: [ platform readDateFromStream: (ReadStream on: '2024-03-15' from: 1 to: 7) for: nil ]
		raise: Error
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamRoundTrip [
	"Dates printed by the platform read back unchanged, whatever their year"

	| platform |
	platform := DatabasePlatform new.
	{ Date year: 2024 month: 3 day: 5.
	  Date year: 2024 month: 12 day: 31.
	  Date year: 5 month: 1 day: 2.
	  Date year: 0 month: 1 day: 1.
	  Date year: -43 month: 3 day: 15.
	  Date year: 9999 month: 12 day: 31.
	  Date year: 12024 month: 1 day: 1.
	  Date year: -12024 month: 1 day: 1 } do: [ :date | | stream |
		stream := WriteStream on: String new.
		platform printDate: date isoFormatOn: stream.
		self
			assert: (platform readDateFromStream: stream contents readStream for: nil)
			equals: date ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamSignedYears [
	"Signed years are the expanded representation: a sign and at least 4 digits, using astronomical numbering (0000 is 1 BCE, -0043 is 44 BCE)"

	| platform |
	platform := DatabasePlatform new.
	{ '-0043-03-15' -> (Date year: -43 month: 3 day: 15).
	  '-0001-12-31' -> (Date year: -1 month: 12 day: 31).
	  '+2024-03-15' -> (Date year: 2024 month: 3 day: 15).
	  '+0000-01-01' -> (Date year: 0 month: 1 day: 1).
	  '-0000-01-01' -> (Date year: 0 month: 1 day: 1) } do: [ :each |
		self
			assert: (platform readDateFromStream: each key readStream for: nil)
			equals: each value ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamStartsAtStreamPosition [
	"Reading starts at the stream's current position, not at the start of its collection"

	| stream |
	stream := 'date: 2024-03-15' readStream.
	stream skip: 6.
	self
		assert: (DatabasePlatform new readDateFromStream: stream for: nil)
		equals: (Date year: 2024 month: 3 day: 15)
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamTrailingCharacters [
	"Only the end of the input, $T or a space may follow the day"

	| platform |
	platform := DatabasePlatform new.
	#('2024-03-15junk' '2024-03-15Z' '2024-03-15/' '2024-03-15-' '2024-03-150') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamValidatesRange [
	"The range of month and day is checked by the Date, leap years included"

	| platform |
	platform := DatabasePlatform new.
	#('2024-02-29' '2000-02-29' '2024-04-30' '2024-12-31') do: [ :each |
		self
			shouldnt: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ].
	#('2023-02-29' '1900-02-29' '2024-02-30' '2024-04-31' '2024-13-01' '2024-00-10' '2024-01-00') do: [ :each |
		self
			should: [ platform readDateFromStream: each readStream for: nil ]
			raise: Error ]
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadDateFromStreamWideString [
	"Wide strings are read too"

	self
		assert: (DatabasePlatform new readDateFromStream: '2024-03-15' asWideString readStream for: nil)
		equals: (Date year: 2024 month: 3 day: 15)
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadTimestamp [

	| ts |
	ts := DatabasePlatform new readTimestamp: '2003-03-03 15:29:28.337-05' for: nil.
	self assert: ts asSeconds + ts offset asSeconds equals: 3224158168.
	self assert: ([ts asMilliseconds + ts offset asMilliSeconds = 3224158168337 ]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #asMilliseconds ]).

	ts := DatabasePlatform new readTimestamp: '2003-03-13 15:29:28.337-05' for: nil.
	self assert: ts asSeconds + ts offset asSeconds equals: 3225022168.
	self assert: ([ts asMilliseconds + ts offset asMilliSeconds = 3225022168337]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #asMilliseconds ])
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadTimestampNoMS [

	| ts |
	ts := DatabasePlatform new readTimestamp: '2003-03-03 15:29:28-05' for: nil.
	self assert: ts year equals: 2003.
	self assert: ts monthIndex equals: 3.
	self assert: ts dayOfMonth equals: 3.
	self assert: ts hours equals: 15.
	self assert: ts minutes equals: 29.
	self assert: ts seconds truncated equals: 28.
	self assert: ([ ts milliseconds = 0 ]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #milliseconds ])
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadTimestampNoMSNoTZ [

	| ts |
	ts := DatabasePlatform new readTimestamp: '2003-03-03 15:29:28' for: nil.
	self assert: ts year equals: 2003.
	self assert: ts monthIndex equals: 3.
	self assert: ts dayOfMonth equals: 3.
	self assert: ts hours equals: 15.
	self assert: ts minutes equals: 29.
	self assert: ts seconds truncated equals: 28.
	self assert: ([ ts milliseconds = 0 ]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #milliseconds ])
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadTimestampNoTZ [

	| ts |
	ts := DatabasePlatform new readTimestamp: '1975-08-13 21:29:28.337' for: nil.
	self assert: ts year equals: 1975.
	self assert: ts monthIndex equals: 8.
	self assert: ts dayOfMonth equals: 13.
	self assert: ts hours equals: 21.
	self assert: ts minutes equals: 29.
	self assert: ts seconds truncated equals: 28.
	self assert: ([ ts milliseconds = 337]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #milliseconds ])
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testReadTimestampOverflowDays [

	| ts |
	ts := DatabasePlatform new readTimestamp: '1975-08-13 21:29:28.337-05' for: nil.
	self assert: ts year equals: 1975.
	self assert: ts monthIndex equals: 8.
	self assert: ts dayOfMonth equals: 13.
	self assert: ts hours equals: 21.
	self assert: ts minutes equals: 29.
	self assert: ts seconds truncated equals: 28.
	self assert: ([ ts milliseconds = 337 ]
		on: MessageNotUnderstood
		do: [ :mnu | mnu return: mnu message selector = #milliseconds ])
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testTrimString1 [
	"Normal ASCII"

	| type plat |
	type := self string20.
	plat := type platform.
	self assert: (plat trimString: 'abcdefghi' for: type) equals: 'abcdefghi'.
	self assert: (plat trimString: 'abcdefghijklmnopqrst' for: type) equals: 'abcdefghijklmnopqrst'.
	self assert: (plat trimString: 'abcdefghijklmnopqrstu' for: type) equals: 'abcdefghijklmnopqrst'.
	self assert: (plat trimString: 'abcdefghijklmnopqrstuvwxy' for: type) equals: 'abcdefghijklmnopqrst'
]

{ #category : #tests }
GlorpDatabasePlatformTest >> testTrimString2 [
	"Some special characters"

	| type plat string |

	type := self string20.
	plat := type platform.

	string := self addToString: 'abcdefghi'.
	self assert: (plat trimString: string for: type) equals: string.
	string := self addToString: 'abcdefghijklmno'.
	self assert: (plat trimString: string for: type) equals: string.
	string := self addToString: 'abcdefghijklmnop'.
	self assert: (plat trimString: string for: type) equals: (string copyFrom: 1 to: string size -1).
	string := self addToString: 'abcdefghijklmnopq'.
	self assert: (plat trimString: string for: type) equals: (string copyFrom: 1 to: string size -1).
	string := (String new: 100000) atAllPut: $a.
	self assert: (plat trimString: string for: type) equals: 'aaaaaaaaaaaaaaaaaaaa'
]
