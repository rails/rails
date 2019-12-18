# frozen_string_literal: true

require "cases/helper"

module ActiveModel
  module Type
    class DateTest < ActiveModel::TestCase
      def test_type_cast_date
        type = Type::Date.new
        assert_nil type.cast(nil)
        assert_nil type.cast("")
        assert_nil type.cast(" ")
        assert_nil type.cast("ABC")

        now = ::Time.now.utc
        values_hash = { 1 => now.year, 2 => now.mon, 3 => now.mday }
        date_string = now.strftime("%F")
        assert_equal date_string, type.cast(date_string).strftime("%F")
        assert_equal date_string, type.cast(values_hash).strftime("%F")
      end

      def test_returns_correct_year
        type = Type::Date.new

        time = ::Time.utc(1, 1, 1)
        date = ::Date.new(time.year, time.mon, time.mday)

        values_hash_for_multiparameter_assignment = { 1 => 1, 2 => 1, 3 => 1 }

        assert_equal date, type.cast(values_hash_for_multiparameter_assignment)
      end
    end
  end
end
