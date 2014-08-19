require 'abstract_unit'
require 'active_support/core_ext/date'
require 'active_support/core_ext/numeric/time'

class TimeTravelTest < ActiveSupport::TestCase
  setup do
    Time.stubs now: Time.now
  end

  teardown do
    travel_back
  end

  def test_time_helper_travel
    expected_time = Time.now + 1.day
    travel 1.day

    assert_equal expected_time.to_s(:db), Time.now.to_s(:db)
    assert_equal expected_time.to_date, Date.today
  end

  def test_time_helper_travel_with_block
    expected_time = Time.now + 1.day

    travel 1.day do
      assert_equal expected_time.to_s(:db), Time.now.to_s(:db)
      assert_equal expected_time.to_date, Date.today
    end

    assert_not_equal expected_time.to_s(:db), Time.now.to_s(:db)
    assert_not_equal expected_time.to_date, Date.today
  end

  def test_time_helper_travel_to
    expected_time = Time.new(2004, 11, 24, 01, 04, 44)
    travel_to expected_time

    assert_equal expected_time, Time.now
    assert_equal Date.new(2004, 11, 24), Date.today
  end

  def test_time_helper_travel_to_with_block
    expected_time = Time.new(2004, 11, 24, 01, 04, 44)

    travel_to expected_time do
      assert_equal expected_time, Time.now
      assert_equal Date.new(2004, 11, 24), Date.today
    end

    assert_not_equal expected_time, Time.now
    assert_not_equal Date.new(2004, 11, 24), Date.today
  end

  def test_time_helper_travel_back
    expected_time = Time.new(2004, 11, 24, 01, 04, 44)

    travel_to expected_time
    assert_equal expected_time, Time.now
    assert_equal Date.new(2004, 11, 24), Date.today
    travel_back

    assert_not_equal expected_time, Time.now
    assert_not_equal Date.new(2004, 11, 24), Date.today
  end

  def test_travel_to_will_reset_the_usec_to_avoid_mysql_rouding
    travel_to Time.utc(2014, 10, 10, 10, 10, 50, 999999) do
      assert_equal 50, Time.now.sec
      assert_equal 0, Time.now.usec
    end
  end
end
