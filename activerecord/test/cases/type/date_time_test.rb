require "cases/helper"
require "models/task"

module ActiveRecord
  module Type
    class DateTimeTest < ActiveRecord::TestCase
      def test_datetime_seconds_precision_applied_to_timestamp
        skip "This test is invalid if subsecond precision isn't supported" unless subsecond_precision_supported?
        p = Task.create!(starting: ::Time.now)
        assert_equal p.starting.usec, p.reload.starting.usec
      end
    end
  end
end
