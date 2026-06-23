# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class ColumnTest < ActiveRecord::TestCase
      def test_auto_populated_is_deprecated_in_favor_of_auto_populated_on_insert
        column = Column.new("token", Type::Value.new, nil, nil, true, "gen_random_uuid()")

        assert_deprecated(/auto_populated_on_insert\?/, ActiveRecord.deprecator) do
          assert_equal column.auto_populated_on_insert?, column.auto_populated?
        end
      end
    end
  end
end
