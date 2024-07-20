module json

import std/num/float64

pub type jvalue
  Null
  Boolean(value: bool)
  Number(value: float64)
  String(value: string)
  Array(values: list<jvalue>)
  Object(entries: list<(string, jvalue)>)
      
pub fun show(this: jvalue): div string
  match this
    Null -> "null"
    Boolean(value) -> value.show.to-lower
    Number(value) -> value.show
    String(value) -> value.show
    Array(values) -> "[" ++ values.map(show).join(", ") ++ "]"
    Object(entries) ->
      val mapped-entries = entries.map fn((key, value))
        key.show ++ ": " ++ value.show
      "{" ++ mapped-entries.join(", ") ++ "}"

pub fun debug(this: jvalue): div string
  match this
    Null -> "Null"
    Boolean(value) -> "Boolean(" ++ value.show ++ ")"
    Number(value) -> "Number(" ++ value.show ++ ")"
    String(value) -> "String(" ++ value.show ++ ")"
    Array(values) -> "Array([" ++ values.map(debug).join(", ") ++ "])"
    Object(entries) ->
      val mapped-entries = entries.map fn((key, value))
        "(" ++ key.show ++ ", " ++ value.debug ++ ")"
      "Object([" ++ mapped-entries.join(", ") ++ "])"