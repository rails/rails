# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/date/calculations"

class DateCalculationsTest < ActiveSupport::TestCase
  def teardown
    Thread.current[:beginning_of_week] = nil
    Date.beginning_of_week_default = nil
  end

  test "beginning_of_week no config" do
    assert_equal :monday, Date.beginning_of_week
  end

  test "beginning_of_week when config.beginning_of_week is set" do
    Date.beginning_of_week_default = :tuesday
    assert_equal :tuesday, Date.beginning_of_week
  end

  test "beginning_of_week when Date.beginning_of_week is set" do
    Date.beginning_of_week = :tuesday
    assert_equal :tuesday, Date.beginning_of_week
  end

  test "beginning_of_week=(week_start) where week_start is valid" do
    assert_equal :monday, Date.beginning_of_week
    Date.beginning_of_week = :tuesday
    assert_equal :tuesday, Date.beginning_of_week
  end

  test "beginning_of_week=(week_start) where week_start is invalid" do
    assert_raise(ArgumentError) { Date.beginning_of_week = "tuesday" }
  end

  test "find_beginning_of_week!(week_start) where week_start is valid" do
    assert_equal :tuesday, Date.find_beginning_of_week!(:tuesday)
  end

  test "find_beginning_of_week!(week_start) where week_start is invalid" do
    assert_raise(ArgumentError) { Date.beginning_of_week = "tuesday" }
  end

  test "yesterday" do
    def current
      Date.new(2020, 04, 26)
    end
    Date.stub :current, current do
      assert_equal Date.new(2020, 04, 25), Date.yesterday
    end
  end

  test "tomorrow" do
    def current
      Date.new(2020, 04, 26)
    end
    Date.stub :current, current do
      assert_equal Date.new(2020, 04, 27), Date.tomorrow
    end
  end

  test "current when Time.zone is set" do
    mock = Minitest::Mock.new
    def mock.today
      Date.new(2020, 04, 25)
    end
    Time.stub :zone, mock do
      assert_equal Date.new(2020, 04, 25), Date.current
    end
  end

  test "current when Time.zone is not set" do
    Date.stub :today, Date.new(2020, 04, 24) do
      assert_equal Date.new(2020, 04, 24), Date.current
    end
  end

  test "ago" do
    assert_equal Time.new(2020, 04, 24, 23, 59, 58), Date.new(2020, 04, 25).ago(2)
  end

  test "since" do
    assert_equal Time.new(2020, 04, 25, 00, 00, 02), Date.new(2020, 04, 25).since(2)
  end

  test "beginning_of_day" do
    assert_equal Time.new(2020, 04, 25, 00, 00, 00), Date.new(2020, 04, 25).beginning_of_day
  end

  test "middle_of_day" do
    assert_equal Time.new(2020, 04, 25, 12, 00, 00), Date.new(2020, 04, 25).middle_of_day
  end

  test "end_of_day" do
    assert_in_delta Time.new(2020, 04, 25, 23, 59, 59), Date.new(2020, 04, 25).end_of_day, 1
    assert_in_delta Time.new(2020, 04, 26, 00, 00, 00), Date.new(2020, 04, 25).end_of_day, 1
  end

  test "plus_with_duration" do
    other = 2
    assert_equal Date.new(2020, 04, 27), Date.new(2020, 04, 25).plus_with_duration(other)
  end

  test "minus_with_duration" do
    other = 2
    assert_equal Date.new(2020, 04, 23), Date.new(2020, 04, 25).minus_with_duration(other)
  end

  test "advance" do
    assert_equal(
      Date.new(2021, 05, 18),
      Date.new(2020, 04, 10).advance(years: 1, months: 1, weeks: 1, days: 1)
    )
  end

  test "change" do
    assert_equal Date.new(2020, 04, 25).change(day: 1), Date.new(2020, 04, 01)
  end

  test "compare_with_coercion" do
    time = Time.new(2020, 04, 25)
    date = Date.new(2020, 04, 25)
    assert date.compare_with_coercion(time)
    assert date.compare_with_coercion(date)
  end
end
