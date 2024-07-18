module parser

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

pub alias parser<a> = string -> div parse-result<a>

pub fun p-literal(literal: string): parser<string>
  fn (input) 
    match input.starts-with(literal)
      Just(rest) -> Success(literal, rest.string)
      Nothing -> Failure(input)

pub fun p-end(): parser<()>
  fn (input)
    if input == "" then Success((), "") else Failure(input)

pub fun p-char-if(f: char -> _ bool): _ parser<char>
  fn (input)
    match input.slice.next
      Just((char, rest)) | f(char) -> Success(char, rest.string)
      _ -> Failure(input)

pub fun p-space(): parser<char>
  p-char-if fn(char) char.is-white

pub fun p-any(): parser<char>
  p-char-if fn(_) True

pub fun p-ignore(): parser<unit>
  p-literal("").ignore

// avoid stack overflows
pub fun p-lazy(get-parser: () -> _ parser<a>): _ parser<a>
  fn (input)
    val parser = get-parser()
    parser(input)

pub fun maybe(parser: parser<a>): _ parser<maybe<a>>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) -> Success(Just(parsed), unparsed)
      Failure(_) -> Success(Nothing, input)

pub fun map(parser: parser<a>, f: a -> _ b): _ parser<b>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) -> Success(f(parsed), unparsed)
      Failure(unparsed) -> Failure(unparsed)

pub fun filter-map(parser: parser<a>, f: a -> _ maybe<b>): _ parser<b>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) ->
        match f(parsed)
          Just(result) -> Success(result, unparsed)
          Nothing -> Failure(unparsed)
      Failure(unparsed) -> Failure(unparsed)

pub fun ignore(parser: parser<a>): _ parser<unit>
  parser.map fn(_) ()

// you could make a version of this that returns either<a,b> for parser<a> and parser<b>
pub fun (||)(parser1: parser<a>, parser2: parser<a>): _ parser<a>
  fn (input)
    match parser1(input)
      Failure(_) -> parser2(input)
      success -> success

pub fun (*)(parser1: parser<a>, parser2: parser<b>): _ parser<(a, b)>
  fn (input)
    match parser1(input)
      Success(parsed1, unparsed1) -> match parser2(unparsed1)
        Success(parsed2, unparsed2) -> Success((parsed1, parsed2), unparsed2)
        Failure(unparsed2) -> Failure(unparsed2) // i think
      Failure(unparsed) -> Failure(unparsed)

// ignore second result
pub fun (!*)(parser1: parser<a>, parser2: parser<b>): _ parser<a>
  (parser1 * parser2).map fn((x, _)) x

// ignore first result
pub fun (*!)(parser1: parser<a>, parser2: parser<b>): _ parser<b>
  (parser1 * parser2).map fn((_, x)) x

pub fun (++)(parser1: parser<a>, parser2: parser<a>, ?(++): (a, a) -> a): _ parser<a>
  (parser1 * parser2).map fn((res1, res2)) res1 ++ res2

pub fun or-blank(parser: parser<string>): _ parser<string>
  parser.maybe.map(fn(opt) opt.default(""))

// currently sep has to be a parser<unit> and parser<b> doesn't work. not quite sure why
pub fun repeat(parser: parser<a>, min: int, max: int = 100_000,
               sep: parser<unit> = p-ignore()): _ parser<list<a>>
  fn (input)
    match parser(input)
      Success(parsed, unparsed) ->
        if max == 0 then Failure(input) // too many matches lol
        else
          match sep(unparsed)
            Success((), unparsed2) ->
              val rest-parser = repeat(parser, min - 1, max - 1, sep)
                .map(fn(result) Cons(parsed, result))
              rest-parser(unparsed2) // gotta look further, then it'll get cons'd
            Failure(unparsed2) ->
              if min > 0 then Failure(unparsed2)
              else Success([parsed], unparsed2)
      Failure(unparsed) ->
        if min > 0 then Failure(unparsed) // more matches were needed
        else Success([], unparsed) // it's fine, we didn't need any more matches

pub fun with-space(parser: parser<a>): _ parser<a>
  (p-space().repeat(0) *! parser) !* p-space().repeat(0)