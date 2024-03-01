# frozen_string_literal: true

require "cases/helper"
require "models/topic"

class TestColumnAlias < ActiveRecord::TestCase
  fixtures :topics

  def test_column_alias
    records = Topic.lease_connection.select_all("SELECT id AS pk FROM topics")
    assert_equal ["pk"], records.columns
  end
end
