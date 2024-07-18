module json-parser

pub import json
pub import parser

pub fun p-json(): _ parser<jvalue>
  p-value().with-space !++ p-end()

pub fun p-value(): _ parser<jvalue>
  p-lazy
    p-null() || p-number() || p-string() ||
    p-boolean() || p-array() || p-object()

pub fun p-null(): _ parser<jvalue>
  p-literal("null").map fn(_) Null

pub fun p-number(): _ parser<jvalue>
  (p-literal("-").maybe ++! p-char-if(is-digit).repeat(1))
    .filter-map(fn(chars) parse-int(chars.string))
    .map(Number)

fun p-quoted(): _ parser<string>
  val non-quote-chars = p-char-if(fn(c) c != '"').repeat(0)
  ((p-literal("\"") ++! non-quote-chars) !++ p-literal("\""))
    .map(fn(chars) chars.string)

pub fun p-string(): _ parser<jvalue>
  p-quoted().map(String)

pub fun p-boolean(): _ parser<jvalue>
  (p-literal("true").map(fn(_) Boolean(True))) ||
  (p-literal("false").map(fn(_) Boolean(False)))

pub fun p-array(): _ parser<jvalue>
  val value-list = p-value().with-space.repeat(0, sep = p-literal(",").ignore)
  ((p-literal("[") ++! value-list) !++ p-literal("]"))
    .map(Array)

pub fun p-object(): _ parser<jvalue>
  val entry = (p-quoted() !++ p-literal(":").with-space) ++ p-value()
  val entry-list = entry.with-space.repeat(0, sep = p-literal(",").ignore)
  ((p-literal("{") ++! entry-list.with-space) !++ p-literal("}"))
    .map(Object)