# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/comment"

class Mysql2ExplainTest < ActiveRecord::Mysql2TestCase
  fixtures :authors
  fixtures :posts
  fixtures :comments

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain
    assert_match %(EXPLAIN for: SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %r(authors |.* const), explain
  end

  def test_explain_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain
    assert_match %(EXPLAIN for: SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %r(authors |.* const), explain
    assert_match %(EXPLAIN for: SELECT `posts`.* FROM `posts` WHERE `posts`.`author_id` = 1), explain
    assert_match %r(posts |.* ALL), explain
  end

  def test_explain_with_json_format
    explain = Author.where(id: 1).explain(format: :json)
    json = JSON.load(explain[0])
    assert_equal "authors", json["query_block"]["table"]["table_name"]
  end

  def test_explain_with_json_format_and_eager_loading
    explain = Author.where(id: 1).includes(posts: [:comments]).explain(format: :json)
    json = JSON.load(explain[2])
    assert_equal "comments", json["query_block"]["table"]["table_name"]
  end

  def test_explain_with_traditional_format
    explain = Author.where(id: 1).explain(format: :traditional)
    assert_match %(EXPLAIN for: SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %r(authors |.* const), explain
  end
end
