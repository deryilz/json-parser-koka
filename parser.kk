module parser

// A result representing the result of a parser once run.
// Either a Success containing data and the rest of the string, or a Failure with an error message
pub type parse-result<a>
  Success(parsed: a, unparsed: string)
  Failure(message: string)

pub fun show(this: parse-result<a>, ?show: a -> _ string): div string
  match this
    Success(a, b) -> "Success(" ++ a.show ++ ", " ++ b.show ++ ")"
    Failure(b) -> "Failure(" ++ b.show ++ ")"

pub fun unwrap(this: parse-result<a>): exn a
  match this
    Success(a, _) -> a
    Failure(_) -> throw("Tried to unwrap parse-result Failure.")

// A parser.
// For simplicity, it's just an alias for a function that takes a string and returns a parse-result of some type.
pub alias parser<a> = string -> div parse-result<a>

// A parser that can pull a string out of the start of an input.
pub fun p-literal(literal: string): parser<string>
  fn (input) 
    match input.starts-with(literal)
      Just(rest) -> Success(literal, rest.string)
      Nothing -> Failure(input)

// A parser that only succeeds if there's nothing left.
pub fun p-end(): parser<unit>
  fn (input)
    if input == "" then Success((), "")
    else Failure(input)

// A parser that pulls a char out of the start of the input, only if it matches a predicate.
pub fun p-char-if(f: char -> _ bool): _ parser<char>
  fn (input)
    match input.slice.next
      Just((char, rest)) | f(char) -> Success(char, rest.string)
      _ -> Failure(input)

// Pulls out any character.
pub fun p-char(): parser<char>
  p-char-if fn(_) True

// Only pulls out a char if it's some kind of whitespace.
pub fun p-space(): parser<char>
  p-char-if fn(char) char.is-white

// A parser that does nothing and always succeeds.
pub fun p-nothing(): parser<unit>
  fn(input) Success((), input)

// Use this to avoid stack overflows for recursive parser definitions.
pub fun p-lazy(get-parser: () -> _ parser<a>): _ parser<a>
  fn (input)
    val parser = get-parser()
    parser(input)

// Makes the parser always "succeed", but expresses failure with Nothing or Just.
pub fun maybe(parser: parser<a>): _ parser<maybe<a>>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) -> Success(Just(parsed), unparsed)
      Failure(_) -> Success(Nothing, input)

// Turns the result into another if the parse is successful.
pub fun map(parser: parser<a>, f: a -> _ b): _ parser<b>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) -> Success(f(parsed), unparsed)
      Failure(message) -> Failure(message)

// Keeps the eventual parse result only if it passes the filter function.
pub fun filter(parser: parser<a>, f: a -> _ bool): _ parser<a>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) ->
        if f(parsed) then Success(parsed, unparsed)
        else Failure("[Filter failed] " ++ unparsed)
      Failure(message) -> Failure(message)

// Equivalent to map(f).filter(is-just).map(unjust).
pub fun filter-map(parser: parser<a>, f: a -> _ maybe<b>): _ parser<b>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) ->
        match f(parsed)
          Just(result) -> Success(result, unparsed)
          Nothing -> Failure(unparsed)
      Failure(message) -> Failure(message)

// Makes it so that the parser returns nothing.
// This is helpful as the sep argument to parser/repeat()
pub fun ignore(parser: parser<a>): _ parser<unit>
  parser.map fn(_) ()

// Takes two parsers of the same type and returns the result of whichever matches first. Order matters.
pub fun (||)(parser1: parser<a>, parser2: parser<a>): _ parser<a>
  fn (input)
    match parser1(input)
      Failure(_) -> parser2(input)
      success -> success

// Returns a new parser than requires both parsers to both succeed.
// If they do, it gives a tuple of both their results.
pub fun (*)(parser1: parser<a>, parser2: parser<b>): _ parser<(a, b)>
  fn (input)
    match parser1(input)
      Success(parsed1, unparsed1) -> match parser2(unparsed1)
        Success(parsed2, unparsed2) -> Success((parsed1, parsed2), unparsed2)
        Failure(message2) -> Failure(message2)
      Failure(message) -> Failure(message)

// Ignore second result.
pub fun (!*)(parser1: parser<a>, parser2: parser<b>): _ parser<a>
  (parser1 * parser2).map fn((x, _)) x

// Ignore first result.
pub fun (*!)(parser1: parser<a>, parser2: parser<b>): _ parser<b>
  (parser1 * parser2).map fn((_, x)) x

// For strings and lists, concats the results of the parsers if they both succeed.
pub fun (++)(parser1: parser<a>, parser2: parser<a>, ?(++): (a, a) -> a): _ parser<a>
  (parser1 * parser2).map fn((res1, res2)) res1 ++ res2

// For string parsers, always succeeds but gives a blank string if it failed.
pub fun or-blank(parser: parser<string>): _ parser<string>
  parser.maybe.map fn(opt) opt.default("")

// Repeats a parser from min..=max times with a seperator in between.
// The default seperator is p-nothing(). Due to typing issues, sep has to be a parser<unit>.
pub fun repeat(parser: parser<a>, min: int, max: int = 100_000,
               sep: parser<unit> = p-nothing()): _ parser<list<a>>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) ->
        if max == 0 then Failure(input) // too many matches
        else
          match sep(unparsed)
            Success((), unparsed2) ->
              val rest-parser = repeat(parser, min - 1, max - 1, sep)
                .map(fn(result) Cons(parsed, result))
              rest-parser(unparsed2) // gotta look further, then it'll get cons'd
            Failure(message2) ->
              if min > 0 then Failure(message2) // seperator failed
              else Success([parsed], unparsed) // at the end, so we don't need a seperator
      Failure(message) ->
        if min > 0 then Failure(message) // not enough matches
        else Success([], input) // it's fine, we didn't need any more matches

// Allows there to be any number of whitespaces before and after the parser.
pub fun with-space(parser: parser<a>): _ parser<a>
  (p-space().repeat(0) *! parser) !* p-space().repeat(0)