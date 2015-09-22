require "cases/helper"
require "models/task"

module ActiveRecord
  module Type
    class IntegerTest < ActiveRecord::TestCase
      def test_datetime_seconds_precision_applied_to_timestamp
        p = Task.create!(starting: ::Time.now)
        assert_equal p.starting.usec, p.reload.starting.usec
      end
    end
  end
end
