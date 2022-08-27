# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class TimeTest < ActiveModel::TestCase
      def test_type_cast_time
        type = Type::Time.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast("ABC")
        assert_nil type.cast(" " * 129)

        time_string = ::Time.now.utc.strftime("%T")
        assert_equal time_string, type.cast(time_string).strftime("%T")

        assert_equal ::Time.utc(2000,  1,  1, 16, 45, 54), type.cast("2015-06-13T19:45:54+03:00")
        assert_equal ::Time.utc(1999, 12, 31, 21,  7,  8), type.cast("06:07:08+09:00")
        assert_equal ::Time.utc(2000,  1,  1, 16, 45, 54), type.cast(4 => 16, 5 => 45, 6 => 54)
      end

      def test_user_input_in_time_zone
        ::Time.use_zone("Pacific Time (US & Canada)") do
          type = Type::Time.new
          assert_nil type.user_input_in_time_zone(nil)
          assert_nil type.user_input_in_time_zone("")
          assert_nil type.user_input_in_time_zone("ABC")
          assert_nil type.user_input_in_time_zone(" " * 129)

          offset = ::Time.zone.formatted_offset
          time_string = "2015-02-09T19:45:54#{offset}"

          assert_equal 19, type.user_input_in_time_zone(time_string).hour
          assert_equal offset, type.user_input_in_time_zone(time_string).formatted_offset
        end
      end
    end
  end
end
