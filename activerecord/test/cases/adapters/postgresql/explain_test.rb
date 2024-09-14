# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"

class PostgreSQLExplainTest < ActiveRecord::PostgreSQLTestCase
  fixtures :authors, :author_addresses

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain.inspect
    assert_match %r(EXPLAIN SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %(QUERY PLAN), explain
  end

  def test_explain_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain.inspect
    assert_match %(QUERY PLAN), explain
    assert_match %r(EXPLAIN SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %r(EXPLAIN SELECT "posts"\.\* FROM "posts" WHERE "posts"\."author_id" = (?:\$1 \[\["author_id", 1\]\]|1)), explain
  end

  def test_explain_with_options_as_symbols
    explain = Author.where(id: 1).explain(:analyze, :buffers).inspect
    assert_match %r(EXPLAIN \(ANALYZE, BUFFERS\) SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %(QUERY PLAN), explain
  end

  def test_explain_with_options_as_strings
    explain = Author.where(id: 1).explain("VERBOSE", "ANALYZE", "FORMAT JSON").inspect
    assert_match %r(EXPLAIN \(VERBOSE, ANALYZE, FORMAT JSON\) SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %(QUERY PLAN), explain
  end

  def test_explain_options_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain(:analyze).inspect
    assert_match %(QUERY PLAN), explain
    assert_match %r(EXPLAIN \(ANALYZE\) SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %r(EXPLAIN \(ANALYZE\) SELECT "posts"\.\* FROM "posts" WHERE "posts"\."author_id" = (?:\$1 \[\["author_id", 1\]\]|1)), explain
  end
end
