Class {
	#name : #GlorpDateTest,
	#superclass : #GlorpDatabaseTypeIndividualDBTests,
	#category : #'Glorp-Integration-Tests-DatabaseTypes'
}

{ #category : #types }
GlorpDateTest >> defaultDatabaseType [
	^self platform date
]

{ #category : #tests }
GlorpDateTest >> testDate [

	| date |
	date := Date today.
	stType := Date.

	self helpTestValue: date.
	self helpTestValue: nil.
]

{ #category : #tests }
GlorpDateTest >> testDateBeforeCommonEra [
	"PostgreSQL stores dates before 1 CE written with its BC suffix. Only the literal is checked: reading such a date back is not supported yet, as P3 parses it ignoring the suffix."

	self platform isPostgreSQLPlatform ifFalse: [ ^ self skip: 'The BC suffix is PostgreSQL specific' ].
	{ (Date year: -43 month: 3 day: 15) -> '0044-03-15 BC'.
	  (Date year: 0 month: 1 day: 1) -> '0001-01-01 BC' } do: [ :each | | literal |
		literal := self platform printDate: each key for: type.
		self
			assert: (session accessor executeSQLString: 'SELECT (' , literal , '::date)::text') first first
			equals: each value ]
]

{ #category : #tests }
GlorpDateTest >> testDateCast [
	"SQLite does not have time-related types:  they are all mapped to strings.  I have not debugged why this test fails yet but assume it is completely unrealistic to expect a string to be cast to a timestamp."

	| date model |
	
	Dialect isPharo ifTrue: [ ^ self skip: 'Pharo does not implement #cast:.' ].
	
	date := Date today.
	session transact: [session register: (GlorpTypeTestsModelClass new test: date)].
	model := session readOneOf: GlorpTypeTestsModelClass where: [:each | (each test cast: session platform date) = date].
	self deny: model isNil
		description: 'This test will fail on SQLite which has no DB Date type;  see test comment'.
	self assert: model test = date.

	model := 	model := session platform isDB2Platform
		ifTrue:
			[session readOneOf: GlorpTypeTestsModelClass where: [:each | (each test timestamp: (each test time0)) = date]]
		ifFalse:
			[session readOneOf: GlorpTypeTestsModelClass where: [:each | (each test cast: session platform timestamp) = date]].
	self deny: model isNil.
	self assert: model test = date.

	model := session readOneOf: GlorpTypeTestsModelClass where: [:each | each test asDate = date].
	self deny: model isNil.
	self assert: model test = date.
]

{ #category : #tests }
GlorpDateTest >> testDateYears [
	"Years below 1000 and above 9999 survive a round trip through the database"

	self platform isPostgreSQLPlatform ifFalse: [ ^ self skip: 'Only checked against PostgreSQL' ].
	stType := Date.
	{ Date year: 5 month: 1 day: 2.
	  Date year: 999 month: 12 day: 31.
	  Date year: 9999 month: 12 day: 31.
	  Date year: 12024 month: 1 day: 1 } do: [ :each | self helpTestValue: each ]
]
