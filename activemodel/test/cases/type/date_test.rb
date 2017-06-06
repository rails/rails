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

        assert_equal ::Date.new(2015, 10, 18), type.cast("2015-10-18")
        assert_equal ::Date.new(2015, 10, 18), type.cast("18/10/2015")
        assert_equal ::Date.new(2015, 10, 18), type.cast("10/18/2015")
      end
    end
  end
end
