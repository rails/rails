# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class DateTimeTest < ActiveModel::TestCase
      def test_type_cast_datetime_and_timestamp
        type = Type::DateTime.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast("  ")
        assert_nil type.cast("ABC")

        datetime_string = ::Time.now.utc.strftime("%FT%T")
        assert_equal datetime_string, type.cast(datetime_string).strftime("%FT%T")
      end

      def test_string_to_time_with_timezone
        ["UTC", "US/Eastern"].each do |zone|
          with_timezone_config default: zone do
            type = Type::DateTime.new
            assert_equal ::Time.utc(2013, 9, 4, 0, 0, 0), type.cast("Wed, 04 Sep 2013 03:00:00 EAT")
          end
        end
      end

      private

        def with_timezone_config(default:)
          old_zone_default = ::Time.zone_default
          ::Time.zone_default = ::Time.find_zone(default)
          yield
        ensure
          ::Time.zone_default = old_zone_default
        end
    end
  end
end
