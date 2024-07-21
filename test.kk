import json-parser

val json = r#"

{
  "first_name": "John",
  "last_name": "Smith",
  "is_alive": true, // this is a comment
  "age": 2700,
  "address": {
    "street_address": "21 2nd Street",
    "city": "New York",
    "state": "NY",
    "postal_code": "10021-3100"
  },
  "phone_numbers": [
    {
      "type": "home",
      "number": "212 555-1234"
    },
    {
      "type": "office", // this is also a comment
      // another comment
      // and another
      "number": "646 555-4567"
    }
  ],
  "children": [
    "Catherine",
    "Thomas",
    "Trevor"
  ] // i can even put comments in funny places
  ,
  "spouse" // like this
  : null
}

"#


fun main()
  val parser = p-json().map(debug)
  val result = parser(json)
  println(result.show)
