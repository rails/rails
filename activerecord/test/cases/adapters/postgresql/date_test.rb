# frozen_string_literal: true

require "cases/helper"
require "models/topic"

class PostgresqlDateTest < ActiveRecord::PostgreSQLTestCase
  def test_load_infinity_and_beyond
    topic = Topic.find_by_sql("SELECT 'infinity'::date AS last_read").first
    assert topic.last_read.infinite?, "timestamp should be infinite"
    assert_operator topic.last_read, :>, 0

    topic = Topic.find_by_sql("SELECT '-infinity'::date AS last_read").first
    assert topic.last_read.infinite?, "timestamp should be infinite"
    assert_operator topic.last_read, :<, 0
  end

  def test_save_infinity_and_beyond
    topic = Topic.create!(last_read: 1.0 / 0.0)
    assert_equal(1.0 / 0.0, topic.last_read)

    topic = Topic.create!(last_read: -1.0 / 0.0)
    assert_equal(-1.0 / 0.0, topic.last_read)
  end
end
