# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"

class PostgreSQLExplainTest < ActiveRecord::PostgreSQLTestCase
  fixtures :authors
  fixtures :posts
  fixtures :comments

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain
    assert_match %r(EXPLAIN for: SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %(QUERY PLAN), explain
  end

  def test_explain_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain
    assert_match %(QUERY PLAN), explain
    assert_match %r(EXPLAIN for: SELECT "authors"\.\* FROM "authors" WHERE "authors"\."id" = (?:\$1 \[\["id", 1\]\]|1)), explain
    assert_match %r(EXPLAIN for: SELECT "posts"\.\* FROM "posts" WHERE "posts"\."author_id" = (?:\$1 \[\["author_id", 1\]\]|1)), explain
  end

  def test_explain_with_json_format_option
    explain = Author.where(id: 1).explain(format: :json)
    assert_match "authors", JSON.parse(explain[0])[0]["Plan"]["Relation Name"]
  end

  def test_explain_with_json_format_and_eager_loading
    explain = Author.where(id: 1).includes(posts: [:comments]).explain(format: :json)
    json = JSON.load(explain[2])[0]
    assert_equal "comments", json["Plan"]["Relation Name"]
  end

  def test_explain_with_yaml_format_option
    explain = Author.where(id: 1).explain(format: :yaml)
    assert_equal "authors", YAML.load(explain[0])[0]["Plan"]["Alias"]
  end

  def test_explain_with_xml_format_option
    explain = Author.where(id: 1).explain(format: :xml)
    xml = ActiveSupport::XmlMini.parse(explain[0])
    assert_equal({ "__content__" => "authors" }, xml["explain"]["Query"]["Plan"]["Relation-Name"])
  end

  def test_explain_with_verbose_option
    explain = Author.where(id: 1).explain(format: :xml, verbose: true)
    assert_match %(<Output>), explain[0]
  end

  def test_explain_with_analyze_option
    explain = Author.where(id: 1).explain(format: :xml, analyze: true)
    assert_match %r{(<Execution-Time>)|(<Total-Runtime>)}, explain[0]
  end
end
