# frozen_string_literal: true

require "cases/helper"
require "support/connection_helper"
require "models/aircraft"

module ActiveRecord
  class TableAliasTest < ActiveRecord::TestCase
    test "it should not use custom alias on insert" do
      captured = capture_sql { Aircraft.create! }
      assert_not_includes captured[0], "AS"
    end

    test "it should update record with custom alias" do
      aircraft = Aircraft.create!
      aircraft.name = "foo"
      captured = capture_sql { aircraft.save! }
      assert_equal Aircraft.table_alias, "a"
      assert_includes captured[0], " AS "
    end

    test "it should delete record with custom alias" do
      aircraft = Aircraft.create!
      captured = capture_sql { aircraft.delete }
      assert_equal Aircraft.table_alias, "a"
      assert_includes captured[0], " AS "
    end
  end
end
