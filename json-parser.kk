module json-parser

pub import json
pub import parser

import std/num/float64

// for now, only inline comments are supported due to weaknesses with the library
fun with-comments(parser: parser<a>): _ parser<a>
  val comment = p-literal("//") * p-char-if(fn(char) char != '\n').repeat(0) * p-literal("\n")
  val comments = comment.with-space.repeat(0).with-space
  (comments *! parser) !* comments

pub fun p-json(): _ parser<jvalue>
  p-value().with-comments !* p-end()

pub fun p-value(): _ parser<jvalue>
  p-lazy
    p-null() || p-number() || p-string() ||
    p-boolean() || p-array() || p-object()

pub fun p-null(): _ parser<jvalue>
  p-literal("null").map fn(_) Null

pub fun p-number(): _ parser<jvalue>
  val neg = p-literal("-")
  val pos = p-literal("+")
  val digits = p-char-if(is-digit).repeat(1).map(string)
  (neg.or-blank
    ++ digits
    ++ (p-literal(".") ++ digits).or-blank
    ++ ((p-literal("e") || p-literal("E")) ++ (neg || pos).or-blank ++ digits).or-blank)
    .filter-map(parse-float64)
    .map(Number)

fun p-quoted(): _ parser<string>
  val non-quote-chars = p-char-if(fn(c) c != '"').repeat(0)
  ((p-literal("\"") *! non-quote-chars) !* p-literal("\""))
    .map(fn(chars) chars.string)

pub fun p-string(): _ parser<jvalue>
  p-quoted().map(String)

pub fun p-boolean(): _ parser<jvalue>
  (p-literal("true").map(fn(_) Boolean(True))) ||
  (p-literal("false").map(fn(_) Boolean(False)))

pub fun p-array(): _ parser<jvalue>
  val value-list = p-value().with-comments.repeat(0, sep = p-literal(",").ignore)
  ((p-literal("[") *! value-list) !* p-literal("]"))
    .map(Array)

pub fun p-object(): _ parser<jvalue>
  val entry = (p-quoted() !* p-literal(":").with-comments) * p-value()
  val entry-list = entry.with-comments.repeat(0, sep = p-literal(",").ignore)
  ((p-literal("{") *! entry-list.with-comments) !* p-literal("}"))
    .map(Object)