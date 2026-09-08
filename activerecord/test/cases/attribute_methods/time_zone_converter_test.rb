# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/enumerable"
require "models/topic"

module ActiveRecord
  module AttributeMethods
    module TimeZoneConversion
      class TimeZoneConverterTest < ActiveRecord::TestCase
        def test_comparison_with_date_time_type
          subtype = ActiveRecord::Type::DateTime.new
          value = ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter.new(subtype)
          value_from_cache = Marshal.load(Marshal.dump(value))

          assert_equal value, value_from_cache
          assert_not_equal value, "foo"
        end

        def test_time_attributes_with_fixed_date_normalization
          old_time_zone = Time.zone

          Time.zone = "Tokyo"

          subtype = ActiveRecord::Type::Time.new
          converter = ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter.new(subtype)

          time_value = converter.cast("14:30")

          assert_equal 2000, time_value.year
          assert_equal 1, time_value.month
          assert_equal 1, time_value.day
          assert_equal 14, time_value.hour
          assert_equal 30, time_value.min

          time_value2 = converter.cast("14:30")

          assert_equal time_value.year, time_value2.year
          assert_equal time_value.month, time_value2.month
          assert_equal time_value.day, time_value2.day
        ensure
          Time.zone = old_time_zone
        end

        def test_time_attribute_dirty_tracking_with_fixed_date
          old_time_zone = Time.zone
          old_default_timezone = ActiveRecord.default_timezone

          Time.zone = "Tokyo"
          ActiveRecord.default_timezone = :utc

          timezone_aware_topic = Class.new(ActiveRecord::Base) do
            self.table_name = "topics"
            self.time_zone_aware_attributes = true
            self.time_zone_aware_types = [:datetime, :time]
            attribute :bonus_time, :time
          end

          topic = timezone_aware_topic.create!(bonus_time: "08:00")
          topic.reload
          topic.bonus_time = "08:00"
          assert_not_predicate topic, :bonus_time_changed?
        ensure
          Time.zone = old_time_zone
          ActiveRecord.default_timezone = old_default_timezone
        end
      end
    end
  end
end
