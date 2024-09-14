# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/enumerable"

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
      end
    end
  end
end
