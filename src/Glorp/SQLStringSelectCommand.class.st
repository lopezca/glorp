"
This is a select command whose SQL is given, rather than being generated from a query.


"
Class {
	#name : #SQLStringSelectCommand,
	#superclass : #QuerySelectCommand,
	#category : #'Glorp-Database'
}

{ #category : #constructor }
SQLStringSelectCommand class >> sqlString: aString parameters: aDictionaryOrArray useBinding: aBoolean session: aSession [

	^ self new
		  setSQLString: aString;
		  parameters: aDictionaryOrArray;
		  useBinding: aBoolean;
		  session: aSession
]

{ #category : #accessing }
SQLStringSelectCommand >> bindingTypes [

	^ query ifNil: [ #(  ) ] ifNotNil: [ super bindingTypes ]
]

{ #category : #accessing }
SQLStringSelectCommand >> bindings [
	"We're not actually sure if we're part of a query with a where clause, or being used in a more ad hoc way. So if we have a query, use either our pre-set parameters, or the query's bindings, whichever produces more. In a tie, pick the query's bindings."

	| queryBindings |
	query ifNil: [ ^ parameters ].
	queryBindings := super bindings.
	^ queryBindings size >= parameters size
		  ifTrue: [ queryBindings ]
		  ifFalse: [ parameters ]
]

{ #category : #accessing }
SQLStringSelectCommand >> blockFactor [

	blockFactor ifNil: [
		blockFactor := query ifNil: [ 5 ] ifNotNil: [ super blockFactor ] ].
	^ blockFactor
]

{ #category : #printing }
SQLStringSelectCommand >> printSQL [
	"We assume the SQL is provided."

	^ self
]

{ #category : #printing }
SQLStringSelectCommand >> setSQLString: aString [

	sqlString := aString
]

{ #category : #reporting }
SQLStringSelectCommand >> tables [

	^ query ifNil: [ Array with: #Unknown ] ifNotNil: [ super tables ]
]
