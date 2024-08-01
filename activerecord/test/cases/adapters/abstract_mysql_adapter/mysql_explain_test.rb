# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"

class MySQLExplainTest < ActiveRecord::AbstractMysqlTestCase
  fixtures :authors, :author_addresses

  def test_explain_for_one_query
    explain = Author.where(id: 1).explain.inspect
    assert_match %(EXPLAIN SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %r(authors |.* const), explain
  end

  def test_explain_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain.inspect
    assert_match %(EXPLAIN SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %r(authors |.* const), explain
    assert_match %(EXPLAIN SELECT `posts`.* FROM `posts` WHERE `posts`.`author_id` = 1), explain
    assert_match %r(posts |.* ALL), explain
  end

  def test_explain_with_options_as_symbol
    explain = Author.where(id: 1).explain(explain_option).inspect
    assert_match %(#{expected_analyze_clause} SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
  end

  def test_explain_with_options_as_strings
    explain = Author.where(id: 1).explain(explain_option.to_s.upcase).inspect
    assert_match %(#{expected_analyze_clause} SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
  end

  def test_explain_options_with_eager_loading
    explain = Author.where(id: 1).includes(:posts).explain(explain_option).inspect
    assert_match %(#{expected_analyze_clause} SELECT `authors`.* FROM `authors` WHERE `authors`.`id` = 1), explain
    assert_match %(#{expected_analyze_clause} SELECT `posts`.* FROM `posts` WHERE `posts`.`author_id` = 1), explain
  end

  private
    def explain_option
      supports_analyze? || supports_explain_analyze? ? :analyze : :extended
    end

    def expected_analyze_clause
      if supports_analyze?
        "ANALYZE"
      elsif supports_explain_analyze?
        "EXPLAIN ANALYZE"
      else
        "EXPLAIN EXTENDED"
      end
    end

    def supports_explain_analyze?
      if conn.mariadb?
        conn.database_version <= "10.0"
      else
        conn.database_version >= "6.0"
      end
    end

    # https://mariadb.com/kb/en/analyze-statement/
    def supports_analyze?
      conn.mariadb? && conn.database_version >= "10.1.0"
    end

    def conn
      ActiveRecord::Base.lease_connection
    end
end
