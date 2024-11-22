# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/time"
require_relative "../time_zone_test_helpers"

class DateAndTimeCompatibilityTest < ActiveSupport::TestCase
  include TimeZoneTestHelpers

  def setup
    @utc_time = Time.utc(2016, 4, 23, 14, 11, 12)
    @date_time = DateTime.new(2016, 4, 23, 14, 11, 12, 0)
    @utc_offset = 3600
    @system_offset = -14400
    @system_dst_offset = -18000
    @zone = ActiveSupport::TimeZone["London"]
  end

  def test_time_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 4, 23, 15, 11, 12, 3600)
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_equal source.object_id, time.object_id
      end
    end
  end

  def test_time_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 4, 23, 15, 11, 12, 3600)
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_equal source.object_id, time.object_id
      end
    end
  end

  def test_time_to_time_on_utc_value_without_preserve_configured
    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 4, 23, 15, 11, 12)
        # No warning because it's already local
        base_time = source.to_time

        utc_time = base_time.getutc
        converted_time = assert_deprecated(ActiveSupport.deprecator) { utc_time.to_time }

        assert_equal source, base_time
        assert_equal source, converted_time
        assert_equal @system_offset, base_time.utc_offset
        assert_equal @system_offset, converted_time.utc_offset
      end
    end

    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 11, 23, 15, 11, 12)
        # No warning because it's already local
        base_time = source.to_time

        utc_time = base_time.getutc
        converted_time = assert_deprecated(ActiveSupport.deprecator) { utc_time.to_time }

        assert_equal source, base_time
        assert_equal source, converted_time
        assert_equal @system_dst_offset, base_time.utc_offset
        assert_equal @system_dst_offset, converted_time.utc_offset
      end
    end
  end

  def test_time_to_time_on_offset_value_without_preserve_configured
    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        foreign_time = Time.new(2016, 4, 23, 15, 11, 12, in: "-0700")
        converted_time = assert_deprecated(ActiveSupport.deprecator) { foreign_time.to_time }

        assert_equal foreign_time, converted_time
        assert_equal @system_offset, converted_time.utc_offset
        assert_not_equal foreign_time.utc_offset, converted_time.utc_offset
      end
    end

    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        foreign_time = Time.new(2016, 11, 23, 15, 11, 12, in: "-0700")
        converted_time = assert_deprecated(ActiveSupport.deprecator) { foreign_time.to_time }

        assert_equal foreign_time, converted_time
        assert_equal @system_dst_offset, converted_time.utc_offset
        assert_not_equal foreign_time.utc_offset, converted_time.utc_offset
      end
    end
  end

  def test_time_to_time_on_tzinfo_value_without_preserve_configured
    foreign_zone = ActiveSupport::TimeZone["America/Phoenix"]

    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        foreign_time = foreign_zone.tzinfo.utc_to_local(Time.new(2016, 4, 23, 15, 11, 12, in: "-0700"))
        converted_time = assert_deprecated(ActiveSupport.deprecator) { foreign_time.to_time }

        assert_equal foreign_time, converted_time
        assert_equal @system_offset, converted_time.utc_offset
        assert_not_equal foreign_time.utc_offset, converted_time.utc_offset
      end
    end

    with_preserve_timezone(nil) do
      with_env_tz "US/Eastern" do
        foreign_time = foreign_zone.tzinfo.utc_to_local(Time.new(2016, 11, 23, 15, 11, 12, in: "-0700"))
        converted_time = assert_deprecated(ActiveSupport.deprecator) { foreign_time.to_time }

        assert_equal foreign_time, converted_time
        assert_equal @system_dst_offset, converted_time.utc_offset
        assert_not_equal foreign_time.utc_offset, converted_time.utc_offset
      end
    end
  end

  def test_time_to_time_frozen_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 4, 23, 15, 11, 12, 3600).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_equal source.object_id, time.object_id
        assert_predicate time, :frozen?
      end
    end
  end

  def test_time_to_time_frozen_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = Time.new(2016, 4, 23, 15, 11, 12, 3600).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_equal source.object_id, time.object_id
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_datetime_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24))
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_datetime_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24))
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_datetime_to_time_frozen_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24)).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_datetime_to_time_frozen_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = DateTime.new(2016, 4, 23, 15, 11, 12, Rational(1, 24)).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_twz_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = ActiveSupport::TimeWithZone.new(@utc_time, @zone)
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @utc_offset, time.utc_offset

        source = ActiveSupport::TimeWithZone.new(@date_time, @zone)
        time = source.to_time

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
        source = ActiveSupport::TimeWithZone.new(@utc_time, @zone)
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset

        source = ActiveSupport::TimeWithZone.new(@date_time, @zone)
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @date_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_twz_to_time_frozen_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = ActiveSupport::TimeWithZone.new(@utc_time, @zone).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_not_predicate time, :frozen?

        source = ActiveSupport::TimeWithZone.new(@date_time, @zone).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @date_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_twz_to_time_frozen_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = ActiveSupport::TimeWithZone.new(@utc_time, @zone).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_predicate time, :frozen?

        source = ActiveSupport::TimeWithZone.new(@date_time, @zone).freeze
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @date_time, time.getutc
        assert_instance_of Time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_string_to_time_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = "2016-04-23T15:11:12+01:00"
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
      end
    end
  end

  def test_string_to_time_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = "2016-04-23T15:11:12+01:00"
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
      end
    end
  end

  def test_string_to_time_frozen_preserves_timezone
    with_preserve_timezone(true) do
      with_env_tz "US/Eastern" do
        source = "2016-04-23T15:11:12+01:00"
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @utc_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_string_to_time_frozen_does_not_preserve_time_zone
    with_preserve_timezone(false) do
      with_env_tz "US/Eastern" do
        source = "2016-04-23T15:11:12+01:00"
        time = source.to_time

        assert_instance_of Time, time
        assert_equal @utc_time, time.getutc
        assert_equal @system_offset, time.utc_offset
        assert_not_predicate time, :frozen?
      end
    end
  end

  def test_to_time_preserves_timezone_is_deprecated
    current_preserve_tz = ActiveSupport.to_time_preserves_timezone

    assert_not_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = :offset
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = false
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = nil
    end

    # When set to nil, the first call will report a deprecation,
    # then switch the configured value to (and return) false.
    assert_deprecated(ActiveSupport.deprecator) do
      assert_equal false, ActiveSupport.to_time_preserves_timezone
    end

    assert_not_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone
    end
  ensure
    ActiveSupport.deprecator.silence do
      ActiveSupport.to_time_preserves_timezone = current_preserve_tz
    end
  end

  def test_to_time_preserves_timezone_supports_new_values
    current_preserve_tz = ActiveSupport.to_time_preserves_timezone

    assert_not_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone
    end

    assert_not_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = :zone
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = :offset
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = true
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = "offset"
    end

    assert_deprecated(ActiveSupport.deprecator) do
      ActiveSupport.to_time_preserves_timezone = :foo
    end
  ensure
    ActiveSupport.deprecator.silence do
      ActiveSupport.to_time_preserves_timezone = current_preserve_tz
    end
  end
end
