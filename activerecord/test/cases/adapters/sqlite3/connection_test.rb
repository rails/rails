# frozen_string_literal: true

require "cases/helper"

class SQLite3ConnectionTest < ActiveRecord::SQLite3TestCase
  fixtures :comments

  def test_truncate
    rows = ActiveRecord::Base.connection.exec_query("select count(*) from comments")
    count = rows.first.values.first
    assert_operator count, :>, 0

    ActiveRecord::Base.connection.truncate("comments")
    rows = ActiveRecord::Base.connection.exec_query("select count(*) from comments")
    count = rows.first.values.first
    assert_equal 0, count
  end
end
