require "cases/helper"
require "active_model/type"

module ActiveModel
  module Type
    class TimeTest < ActiveModel::TestCase
      def test_type_cast_time
        type = Type::Time.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast("ABC")

        time_string = ::Time.now.utc.strftime("%T")
        assert_equal time_string, type.cast(time_string).strftime("%T")

        assert_equal ::Time.utc(2000,  1,  1, 16, 45, 54), type.cast("2015-06-13T19:45:54+03:00")
        assert_equal ::Time.utc(1999, 12, 31, 21,  7,  8), type.cast("06:07:08+09:00")
      end
    end
  end
end
