require 'abstract_unit'
require 'active_support/core_ext/date_time'
require 'active_support/core_ext/numeric/time'

class TimeTravelTest < ActiveSupport::TestCase
  teardown do
    travel_back
  end

  def test_time_helper_travel
    Time.stub(:now, Time.now) do
      expected_time = Time.now + 1.day
      travel 1.day

      assert_equal expected_time.to_s(:db), Time.now.to_s(:db)
      assert_equal expected_time.to_date, Date.today
      assert_equal expected_time.to_datetime.to_s(:db), DateTime.now.to_s(:db)
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
      expected_time = Time.new(2004, 11, 24, 01, 04, 44)
      travel_to expected_time

      assert_equal expected_time, Time.now
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now
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
      expected_time = Time.new(2004, 11, 24, 01, 04, 44)

      travel_to expected_time
      assert_equal expected_time, Time.now
      assert_equal Date.new(2004, 11, 24), Date.today
      assert_equal expected_time.to_datetime, DateTime.now
      travel_back

      assert_not_equal expected_time, Time.now
      assert_not_equal Date.new(2004, 11, 24), Date.today
      assert_not_equal expected_time.to_datetime, DateTime.now
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

  def test_nested_travel
    travel 1.day do
      time_1 = Time.current
      date_1 = Date.today
      d_time_1 = DateTime.now

      travel 1.day do
        time_2 = Time.current
        date_2 = Date.today
        d_time_2 = DateTime.now

        travel 1.day do
          time_3 = Time.current
          date_3 = Date.today
          d_time_3 = DateTime.now

          assert_equal time_3, Time.current
          assert_equal date_3, Date.today
          assert_equal d_time_3, DateTime.now
        end

        assert_equal time_2, Time.current
        assert_equal date_2, Date.today
        assert_equal d_time_2, DateTime.now
      end

      assert_equal time_1, Time.current
      assert_equal date_1, Date.today
      assert_equal d_time_1, DateTime.now
    end
  end
end
