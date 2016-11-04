require "abstract_unit"
require "active_support/time"
require "time_zone_test_helpers"

class DateAndTimeCompatibilityTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @utc_time = Time.utc(2016, 4, 23, 14, 11, 12)
    @date_time = DateTime.new(2016, 4, 23, 14, 11, 12, 0)
    @utc_offset = 3600
    @system_offset = -14400
    @zone = ActiveSupport::TimeZone["London"]
  end

  def test_time_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        time = Time.new(2016, 4, 23, 15, 11, 12, 3600).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_time_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        time = Time.new(2016, 4, 23, 15, 11, 12, 3600).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_datetime_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        time = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24)).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_datetime_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        time = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24)).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_twz_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        time = ActiveSupport::TimeWithZone.new(@utc_time, @zone).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @utc_offset, time.utc_offset

        time = ActiveSupport::TimeWithZone.new(@date_time, @zone).to_time

        assert_instance_of Time, time
        assert_equal @date_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_twz_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        time = ActiveSupport::TimeWithZone.new(@utc_time, @zone).to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset

        time = ActiveSupport::TimeWithZone.new(@date_time, @zone).to_time

        assert_instance_of Time, time
        assert_equal @date_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_string_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        time = "2016-04-23T15:11:12+01:00".to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_string_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        time = "2016-04-23T15:11:12+01:00".to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end
end
