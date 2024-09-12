# frozen_string_literal: true

require "cases/helper"
require "models/task"

module ActiveRecord
  module Type
    class DateTimeTest < ActiveRecord::TestCase
      def test_datetime_seconds_precision_applied_to_timestamp
        p = Task.create!(starting: ::Time.now)
        assert_equal p.starting.usec, p.reload.starting.usec
      end

      test "serialize_cast_value is equivalent to serialize after cast" do
        type = Type::DateTime.new(precision: 1)
        value = type.cast("1999-12-31 12:34:56.789 -1000")

        assert_equal type.serialize(value), type.serialize_cast_value(value)
      end
    end
  end
end
