# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/core_ext/date_time"
require "active_support/core_ext/numeric/time"
require "active_support/core_ext/string/conversions"
require_relative "time_zone_test_helpers"

class TimeTravelTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  class TimeSubclass < ::Time; end
  class DateSubclass < ::Date; end
  class DateTimeSubclass < ::DateTime; end

  class TravelClass
    include ActiveSupport::Testing::TimeHelpers

    def travel_to_no_block(date)
      travel_to(date)
    end

    def travel_to_block(date)
      travel_to(date) { }
    end
  end

  def test_time_helper_travel
    Time.stub(:now, Time.now) do
      expected_time = Time.now + 1.day
      travel 1.day

      assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
      assert_equal expected_time.to_date, Date.today
      assert_equal expected_time.to_datetime.to_fs(:db), DateTime.now.to_fs(:db)

      assert_equal expected_time.to_fs(:db), Time.new.to_fs(:db)
      assert_not_equal expected_time.to_fs(:db), Time.new(precision: 3).to_fs(:db)
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_with_block
    Time.stub(:now, Time.now) do
      expected_time = Time.now + 1.day

      travel 1.day do
        assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
        assert_equal expected_time.to_date, Date.today
        assert_equal expected_time.to_datetime.to_fs(:db), DateTime.now.to_fs(:db)

        assert_equal expected_time.to_fs(:db), Time.new.to_fs(:db)
        assert_not_equal expected_time.to_fs(:db), Time.new(precision: 3).to_fs(:db)
        assert_equal Time.new("2000-12-31 23:59:59.567"), Time.new("2000-12-31 23:59:59.56789", precision: 3)
      end

      assert_not_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
      assert_not_equal expected_time.to_date, Date.today
      assert_not_equal expected_time.to_datetime.to_fs(:db), DateTime.now.to_fs(:db)
      assert_equal Time.new("2000-12-31 23:59:59.567"), Time.new("2000-12-31 23:59:59.56789", precision: 3)
    end
  end

  def test_time_helper_travel_to
    Time.stub(:now, Time.now) do
      expected_time = Time.new(2004, 11, 24, 1, 4, 44)
      travel_to expected_time

      assert_equal expected_time, Time.now
      assert_equal expected_time, Time.new
      assert_not_equal expected_time, Time.new(2004, 11, 25)
      assert_not_equal expected_time, Time.new(precision: 3)
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_to_with_block
    Time.stub(:now, Time.now) do
      expected_time = Time.new(2004, 11, 24, 1, 4, 44)

      travel_to expected_time do
        assert_equal expected_time, Time.now
        assert_equal expected_time, Time.new
        assert_not_equal expected_time, Time.new(precision: 3)
        assert_not_equal expected_time, Time.new(2004, 11, 25)
        assert_equal Date.new(2004, 11, 24), Date.today
        assert_equal expected_time.to_datetime, DateTime.now
      end

      assert_not_equal expected_time, Time.now
      assert_not_equal expected_time, Time.new
      assert_not_equal Date.new(2004, 11, 24), Date.today
      assert_not_equal expected_time.to_datetime, DateTime.now
    end
  end

  def test_time_helper_travel_to_with_time_zone
    with_env_tz "US/Eastern" do
      with_tz_default ActiveSupport::TimeZone["UTC"] do
        Time.stub(:now, Time.now) do
          expected_time = 5.minutes.ago

          travel_to 5.minutes.ago do
            assert_equal expected_time.to_fs(:db), Time.zone.now.to_fs(:db)
          end
        end
      end
    end
  end

  def test_time_helper_travel_to_with_different_system_and_application_time_zones
    with_env_tz "US/Eastern" do # system time zone: -05
      expected_time_in_2021 = Time.new(2021)

      with_tz_default ActiveSupport::TimeZone["Ekaterinburg"] do # application time zone: +05
        destination_time = Time.new(2023, 12, 1, 5, 6, 7, 5 * 3600)

        # All stubbed methods are expected to return values in system (-05) time zone
        expected_utc_offset = -5 * 3600
        expected_time = Time.new(2023, 11, 30, 19, 6, 7, expected_utc_offset)
        expected_datetime = DateTime.new(2023, 11, 30, 19, 6, 7, -Rational(5, 24))
        expected_date = Date.new(2023, 11, 30)

        travel_to destination_time do
          assert_equal expected_time, Time.now
          assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
          assert_equal expected_utc_offset, Time.now.utc_offset

          assert_equal expected_datetime, DateTime.now
          assert_equal expected_datetime.to_fs(:db), DateTime.now.to_fs(:db)
          assert_equal expected_utc_offset, DateTime.now.utc_offset

          assert_equal expected_date, Date.today

          # Time.new with no args equals to Time.now
          assert_equal expected_time, Time.new
          assert_equal expected_time.to_fs(:db), Time.new.to_fs(:db)
          assert_equal expected_utc_offset, Time.new.utc_offset

          # Time.new with any args falls back to original Ruby implementation
          assert_equal expected_time_in_2021, Time.new(2021)
          assert_equal expected_time_in_2021.to_fs(:db), Time.new(2021).to_fs(:db)
          assert_equal expected_time_in_2021.utc_offset, Time.new(2021).utc_offset
        end
      end
    end
  end

  def test_time_helper_travel_to_with_string_for_time_zone
    with_env_tz "US/Eastern" do
      with_tz_default ActiveSupport::TimeZone["UTC"] do
        Time.stub(:now, Time.now) do
          expected_time = Time.new(2004, 11, 24, 1, 4, 44)

          travel_to "2004-11-24 01:04:44" do
            assert_equal expected_time.to_fs(:db), Time.zone.now.to_fs(:db)
          end
        end
      end
    end
  end

  def test_time_helper_travel_to_with_string_and_milliseconds
    with_env_tz "US/Eastern" do
      with_tz_default ActiveSupport::TimeZone["UTC"] do
        Time.stub(:now, Time.now) do
          expected_time = Time.new(2004, 11, 24, 1, 4, 44)

          travel_to "2004-11-24T01:04:44.123-05:00" do
            assert_equal expected_time, Time.zone.now
          end
        end
      end
    end
  end

  def test_time_helper_travel_to_with_separate_class
    travel_object = TravelClass.new
    date1 = Date.new(2004, 11, 24)
    date2 = Date.new(2005, 11, 24)

    Time.stub(:now, now = Time.now) do
      travel_to(date1) do
        travel_object.travel_to_no_block(date2)
      end
      assert_equal now, Time.now

      travel_to(date1) do
        travel_object.travel_to_no_block(date2)
        assert_equal date2, Date.today
      end
      assert_equal now, Time.now

      travel_to(date1) do
        travel_object.travel_to_block(date2)
        assert_equal date1, Date.today
      end
      assert_equal now, Time.now
    end
  end

  def test_time_helper_travel_back
    Time.stub(:now, Time.now) do
      expected_time = Time.new(2004, 11, 24, 1, 4, 44)

      travel_to expected_time
      assert_equal expected_time, Time.now
      assert_equal expected_time, Time.new
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now
      travel_back

      assert_not_equal expected_time, Time.now
      assert_not_equal expected_time, Time.new
      assert_not_equal Date.new(2004, 11, 24), Date.today
      assert_not_equal expected_time.to_datetime, DateTime.now
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_back_with_block
    Time.stub(:now, Time.now) do
      expected_time = Time.new(2004, 11, 24, 1, 4, 44)

      travel_to expected_time
      assert_equal expected_time, Time.now
      assert_equal expected_time, Time.new
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now

      travel_back do
        assert_not_equal expected_time, Time.now
        assert_not_equal expected_time, Time.new
        assert_not_equal Date.new(2004, 11, 24), Date.today
        assert_not_equal expected_time.to_datetime, DateTime.now
      end

      assert_equal expected_time, Time.now
      assert_equal expected_time, Time.new
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_to_with_nested_calls_with_blocks
    Time.stub(:now, Time.now) do
      outer_expected_time = Time.new(2004, 11, 24, 1, 4, 44)
      inner_expected_time = Time.new(2004, 10, 24, 1, 4, 44)
      travel_to outer_expected_time do
        e = assert_raises(RuntimeError) do
          travel_to(inner_expected_time) do
            # noop
          end
        end
        assert_match(/Calling `travel_to` with a block, when we have previously already made a call to `travel_to`, can lead to confusing time stubbing\./, e.message)
      end
    end
  end

  def test_time_helper_travel_to_with_nested_calls
    Time.stub(:now, Time.now) do
      outer_expected_time = Time.new(2004, 11, 24, 1, 4, 44)
      inner_expected_time = Time.new(2004, 10, 24, 1, 4, 44)
      travel_to outer_expected_time do
        assert_nothing_raised do
          travel_to(inner_expected_time)

          assert_equal inner_expected_time, Time.now
        end
      end
    end
  end

  def test_time_helper_travel_to_with_subsequent_calls
    Time.stub(:now, Time.now) do
      initial_expected_time = Time.new(2004, 11, 24, 1, 4, 44)
      subsequent_expected_time = Time.new(2004, 10, 24, 1, 4, 44)
      assert_nothing_raised do
        travel_to initial_expected_time
        travel_to subsequent_expected_time

        assert_equal subsequent_expected_time, Time.now

        travel_back
      end
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_to_with_usec
    Time.stub(:now, Time.now) do
      duration_usec = 0.1.seconds
      traveled_time = Time.new(2004, 11, 24, 1, 4, 44) + duration_usec
      expected_time = Time.new(2004, 11, 24, 1, 4, 44)

      assert_nothing_raised do
        travel_to traveled_time

        assert_equal expected_time, Time.now

        travel_back
      end
    ensure
      travel_back
    end
  end

  def test_time_helper_with_usec_true
    Time.stub(:now, Time.now) do
      duration_usec = 0.1.seconds
      expected_time = Time.new(2004, 11, 24, 1, 4, 44) + duration_usec

      assert_nothing_raised do
        travel_to expected_time, with_usec: true

        assert_equal expected_time.to_f, Time.now.to_f

        travel 0.5, with_usec: true

        assert_equal((expected_time + 0.5).to_f, Time.now.to_f)

        travel_back
      end
    ensure
      travel_back
    end
  end

  def test_time_helper_travel_to_with_datetime_and_usec
    with_env_tz "US/Eastern" do
      with_tz_default ActiveSupport::TimeZone["UTC"] do
        Time.stub(:now, Time.now) do
          duration_usec = 0.1.seconds
          traveled_time = DateTime.iso8601("2004-11-24T01:04:44.000-05:00") + duration_usec
          expected_time = Time.new(2004, 11, 24, 1, 4, 44)

          assert_nothing_raised do
            travel_to traveled_time

            assert_equal expected_time, Time.zone.now

            travel_back
          end
        ensure
          travel_back
        end
      end
    end
  end

  def test_time_helper_travel_to_with_datetime_and_usec_true
    with_env_tz "US/Eastern" do
      with_tz_default ActiveSupport::TimeZone["UTC"] do
        Time.stub(:now, Time.now) do
          duration_usec = 0.1.seconds
          traveled_time = DateTime.iso8601("2004-11-24T01:04:44.000-05:00") + duration_usec
          expected_time = Time.new(2004, 11, 24, 1, 4, 44) + duration_usec

          assert_nothing_raised do
            travel_to traveled_time, with_usec: true

            assert_equal expected_time, Time.now

            travel_back
          end
        ensure
          travel_back
        end
      end
    end
  end

  def test_time_helper_travel_to_with_string_and_usec
    with_tz_default ActiveSupport::TimeZone["UTC"] do
      Time.stub(:now, Time.now) do
        duration_usec = 0.1.seconds
        traveled_time = Time.new(2004, 11, 24, 1, 4, 44) + duration_usec
        expected_time = Time.new(2004, 11, 24, 1, 4, 44)

        assert_nothing_raised do
          travel_to traveled_time.iso8601(3)

          assert_equal expected_time, Time.now

          travel_back
        end
      ensure
        travel_back
      end
    end
  end

  def  test_time_helper_travel_to_with_string_and_usec_true
    with_tz_default ActiveSupport::TimeZone["UTC"] do
      Time.stub(:now, Time.now) do
        duration_usec = 0.1.seconds
        expected_time = Time.new(2004, 11, 24, 1, 4, 44) + duration_usec

        assert_nothing_raised do
          travel_to expected_time.iso8601(3), with_usec: true

          assert_equal expected_time.to_f, Time.now.to_f

          travel 0.5, with_usec: true

          assert_equal((expected_time + 0.5).to_f, Time.now.to_f)

          travel_back
        end
      ensure
        travel_back
      end
    end
  end

  def test_time_helper_freeze_time_with_usec_true
    # repeatedly test in case Time.now happened to actually be 0 usec
    checks = 9.times.map do
      freeze_time(with_usec: true) do
        Time.now.usec != 0
      end
    end
    assert_predicate checks, :any?
  end

  def test_time_helper_travel_with_subsequent_block
    Time.stub(:now, Time.now) do
      outer_expected_time = Time.new(2004, 11, 24, 1, 4, 44)
      inner_expected_time = Time.new(2004, 10, 24, 1, 4, 44)
      travel_to outer_expected_time

      assert_equal outer_expected_time, Time.now

      assert_nothing_raised do
        travel_to(inner_expected_time) do
          assert_equal inner_expected_time, Time.now
        end
      end

      assert_equal outer_expected_time, Time.now
    ensure
      travel_back
    end
  end

  def test_travel_to_will_reset_the_usec_to_avoid_mysql_rounding
    Time.stub(:now, Time.now) do
      travel_to Time.utc(2014, 10, 10, 10, 10, 50, 999999) do
        assert_equal 50, Time.now.sec
        assert_equal 0, Time.now.usec
        assert_equal 50, DateTime.now.sec
        assert_equal 0, DateTime.now.usec
      end
    end
  end

  def test_time_helper_travel_with_time_subclass
    assert_equal TimeSubclass, TimeSubclass.now.class
    assert_equal DateSubclass, DateSubclass.today.class
    assert_equal DateTimeSubclass, DateTimeSubclass.now.class

    travel 1.day do
      assert_equal TimeSubclass, TimeSubclass.now.class
      assert_equal DateSubclass, DateSubclass.today.class
      assert_equal DateTimeSubclass, DateTimeSubclass.now.class
      assert_equal Time.now.to_s, TimeSubclass.now.to_s
      assert_equal Date.today.to_s, DateSubclass.today.to_s
      assert_equal DateTime.now.to_s, DateTimeSubclass.now.to_s
    end
  end

  def test_time_helper_freeze_time
    expected_time = Time.now
    freeze_time
    sleep(1)

    assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
  ensure
    travel_back
  end

  def test_time_helper_freeze_time_with_time_arg
    expected_time = Time.now + 1.day
    freeze_time expected_time
    sleep(1)

    assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
  ensure
    travel_back
  end

  def test_time_helper_freeze_time_with_block
    expected_time = Time.now

    freeze_time do
      sleep(1)

      assert_equal expected_time.to_fs(:db), Time.now.to_fs(:db)
    end

    assert_operator expected_time.to_fs(:db), :<, Time.now.to_fs(:db)
  end

  def test_time_helper_unfreeze_time
    assert_equal method(:travel_back), method(:unfreeze_time)
  end
end
