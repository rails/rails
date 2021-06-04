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
end
