
db = require "lapis.nginx.postgres"

value_table = { hello: "world", age: 34 }

tests = {
  {
    -> db.escape_identifier "dad"
    '"dad"'
  }
  {
    -> db.escape_identifier "select"
    '"select"'
  }
  {
    -> db.escape_identifier 'love"fish'
    '"love""fish"'
  }
  {
    -> db.escape_literal 3434
    "3434"
  }
  {
    -> db.escape_literal "cat's soft fur"
    "'cat''s soft fur'"
  }
  {
    -> db.interpolate_query "select * from cool where hello = ?", "world"
    "select * from cool where hello = 'world'"
  }

  {
    -> db.encode_values(value_table)
    [[("hello", "age") VALUES ('world', 34)]]
    [[("age", "hello") VALUES (34, 'world')]]
  }

  {
    -> db.encode_assigns(value_table)
    [["hello" = 'world', "age" = 34]]
    [["age" = 34, "hello" = 'world']]
  }

  {
    -> db.interpolate_query "update x set x = ?", db.raw"y + 1"
    "update x set x = y + 1"
  }

  {
    -> db.insert "cats", age: 123, name: "catter"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123)]]
  }

  {
    -> db.update "cats", { age: db.raw"age - 10" }, "name = ?", "catter"
    [[UPDATE "cats" SET "age" = age - 10 WHERE name = 'catter']]
  }

  {
    -> db.update "cats", { age: db.raw"age - 10" }, { name: db.NULL }
    [[UPDATE "cats" SET "age" = age - 10 WHERE "name" = NULL]]
  }

  {
    -> db.update "cats", { color: "red" }, { weight: 1200, length: 392 }
    [[UPDATE "cats" SET "color" = 'red' WHERE "weight" = 1200 AND "length" = 392]]
    [[UPDATE "cats" SET "color" = 'red' WHERE "length" = 392 AND "weight" = 1200]]
  }

  {
    -> db.delete "cats"
    [[DELETE FROM "cats"]]
  }

  {
    -> db.delete "cats", "name = ?", "rump"
    [[DELETE FROM "cats" WHERE name = 'rump']]
  }

  {
    -> db.delete "cats", name: "rump"
    [[DELETE FROM "cats" WHERE "name" = 'rump']]
  }

  {
    -> db.delete "cats", name: "rump", dad: "duck"
    [[DELETE FROM "cats" WHERE "name" = 'rump' AND "dad" = 'duck']]
    [[DELETE FROM "cats" WHERE "dad" = 'duck' AND "name" = 'rump']]
  }

  {
    -> db.insert "cats", { hungry: true }
    [[INSERT INTO "cats" ("hungry") VALUES (TRUE)]]
  }


  {
    -> db.insert "cats", { age: 123, name: "catter" }, "age"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123) RETURNING "age"]]
    [[INSERT INTO "cats" ("age", "name") VALUES (123, 'catter') RETURNING "age"]]
  }

  {
    -> db.insert "cats", { age: 123, name: "catter" }, "age", "name"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123) RETURNING "age", "name"]]
    [[INSERT INTO "cats" ("age", "name") VALUES (123, 'catter') RETURNING "age", "name"]]
  }

}

one_of = (state, arguments) ->
  { input, expected } = arguments

  for e in *expected
    return true if input == e

  false

s = require "say"

s\set "assertion.one_of.positive",
  "Expected %s to be one of:\n%s"

s\set "assertion.one_of.negative",
  "Expected property %s to not be in:\n%s"

assert\register "assertion",
  "one_of", one_of, "assertion.one_of.positive", "assertion.one_of.negative"

with_query_fn = (q, run using db) ->
  old = db._get_query_fn!
  db._set_query_fn q
  with run!
    db._set_query_fn old

local old_query_fn
describe "lapis.nginx.postgres", ->
  setup ->
    old_query_fn = db._get_query_fn!
    db._set_query_fn (q) -> q

  teardown ->
    db._set_query_fn old_query_fn

  for group in *tests
    it "should match", ->
      input = group[1]!
      if #group > 2
        assert.one_of input, { unpack group, 2 }
      else
        assert.same input, group[2]

  it "should match", ->
    with_query_fn ((q) -> resultset: q), ->
      input = db.select "* from things where id = ?", "cool days"
      output = "SELECT * from things where id = 'cool days'"
      assert.same input, output


