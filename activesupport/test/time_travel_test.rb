require "abstract_unit"
require "active_support/core_ext/date_time"
require "active_support/core_ext/numeric/time"

class TimeTravelTest < ActiveSupport::TestCase
  def test_time_helper_travel
    Time.stub(:now, Time.now) do
      begin
        expected_time = Time.now + 1.day
        travel 1.day

        assert_equal expected_time.to_s(:db), Time.now.to_s(:db)
        assert_equal expected_time.to_date, Date.today
        assert_equal expected_time.to_datetime.to_s(:db), DateTime.now.to_s(:db)
      ensure
        travel_back
      end
    end
  end

  def test_time_helper_travel_with_block
    Time.stub(:now, Time.now) do
      expected_time = Time.now + 1.day

      travel 1.day do
        assert_equal expected_time.to_s(:db), Time.now.to_s(:db)
        assert_equal expected_time.to_date, Date.today
        assert_equal expected_time.to_datetime.to_s(:db), DateTime.now.to_s(:db)
      end

      assert_not_equal expected_time.to_s(:db), Time.now.to_s(:db)
      assert_not_equal expected_time.to_date, Date.today
      assert_not_equal expected_time.to_datetime.to_s(:db), DateTime.now.to_s(:db)
    end
  end

  def test_time_helper_travel_to
    Time.stub(:now, Time.now) do
      begin
        expected_time = Time.new(2004, 11, 24, 01, 04, 44)
        travel_to expected_time

        assert_equal expected_time, Time.now
        assert_equal Date.new(2004, 11, 24), Date.today
        assert_equal expected_time.to_datetime, DateTime.now
      ensure
        travel_back
      end
    end
  end

  def test_time_helper_travel_to_with_block
    Time.stub(:now, Time.now) do
      expected_time = Time.new(2004, 11, 24, 01, 04, 44)

      travel_to expected_time do
        assert_equal expected_time, Time.now
        assert_equal Date.new(2004, 11, 24), Date.today
        assert_equal expected_time.to_datetime, DateTime.now
      end

      assert_not_equal expected_time, Time.now
      assert_not_equal Date.new(2004, 11, 24), Date.today
      assert_not_equal expected_time.to_datetime, DateTime.now
    end
  end

  def test_time_helper_travel_back
    Time.stub(:now, Time.now) do
      begin
        expected_time = Time.new(2004, 11, 24, 01, 04, 44)

        travel_to expected_time
        assert_equal expected_time, Time.now
        assert_equal Date.new(2004, 11, 24), Date.today
        assert_equal expected_time.to_datetime, DateTime.now
        travel_back

        assert_not_equal expected_time, Time.now
        assert_not_equal Date.new(2004, 11, 24), Date.today
        assert_not_equal expected_time.to_datetime, DateTime.now
      ensure
        travel_back
      end
    end
  end

  def test_time_helper_travel_to_with_nested_calls_with_blocks
    Time.stub(:now, Time.now) do
      outer_expected_time = Time.new(2004, 11, 24, 01, 04, 44)
      inner_expected_time = Time.new(2004, 10, 24, 01, 04, 44)
      travel_to outer_expected_time do
        assert_raises(RuntimeError, /Calling `travel_to` with a block, when we have previously already made a call to `travel_to`, can lead to confusing time stubbing./) do
          travel_to(inner_expected_time) do
            #noop
          end
        end
      end
    end
  end

  def test_time_helper_travel_to_with_nested_calls
    Time.stub(:now, Time.now) do
      outer_expected_time = Time.new(2004, 11, 24, 01, 04, 44)
      inner_expected_time = Time.new(2004, 10, 24, 01, 04, 44)
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
      begin
        initial_expected_time = Time.new(2004, 11, 24, 01, 04, 44)
        subsequent_expected_time = Time.new(2004, 10, 24, 01, 04, 44)
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
  end

  def test_travel_to_will_reset_the_usec_to_avoid_mysql_rouding
    Time.stub(:now, Time.now) do
      travel_to Time.utc(2014, 10, 10, 10, 10, 50, 999999) do
        assert_equal 50, Time.now.sec
        assert_equal 0, Time.now.usec
        assert_equal 50, DateTime.now.sec
        assert_equal 0, DateTime.now.usec
      end
    end
  end
end
