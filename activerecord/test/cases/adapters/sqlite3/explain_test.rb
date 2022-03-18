# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"

class SQLite3ExplainTest < ActiveRecord::SQLite3TestCase
  fixtures :authors, :author_addresses

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain
    assert_match %r(EXPLAIN for: SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\? \[\["id", 1\]\]|1)), explain
    assert_match(/(SEARCH )?(TABLE )?authors USING (INTEGER )?PRIMARY KEY/, explain)
  end

  def test_explain_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain
    assert_match %r(EXPLAIN for: SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\? \[\["id", 1\]\]|1)), explain
    assert_match(/(SEARCH )?(TABLE )?authors USING (INTEGER )?PRIMARY KEY/, explain)
    assert_match %r(EXPLAIN for: SELECT "posts"\.\* FROM "posts" WHERE "posts"\."author_id" = (?:\? \[\["author_id", 1\]\]|1)), explain
    assert_match(/(SEARCH |(SCAN )?(TABLE ))posts/, explain)
  end
end
