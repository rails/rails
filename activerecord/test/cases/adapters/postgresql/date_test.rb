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

  def test_bc_date
    date = Date.new(0) - 1.week
    topic = Topic.create!(last_read: date)
    assert_equal date, Topic.find(topic.id).last_read
  end

  def test_bc_date_leap_year
    date = Time.utc(-4, 2, 29).to_date
    topic = Topic.create!(last_read: date)
    assert_equal date, Topic.find(topic.id).last_read
  end

  def test_bc_date_year_zero
    date = Time.utc(0, 4, 7).to_date
    topic = Topic.create!(last_read: date)
    assert_equal date, Topic.find(topic.id).last_read
  end
end
