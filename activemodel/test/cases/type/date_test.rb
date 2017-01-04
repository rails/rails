require "cases/helper"
require "active_model/type"

module ActiveModel
  module Type
    class DateTest < ActiveModel::TestCase
      def test_type_cast_date
        type = Type::Date.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast(" ")
        assert_nil type.cast("ABC")

        date_string = ::Time.now.utc.strftime("%F")
        assert_equal date_string, type.cast(date_string).strftime("%F")
      end
    end
  end
end
