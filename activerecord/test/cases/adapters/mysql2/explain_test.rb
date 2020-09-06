# frozen_string_literal: true

require 'cases/helper'
require 'models/author'
require 'models/post'

class Mysql2ExplainTest < ActiveRecord::Mysql2TestCase
  fixtures :authors

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
end
