# frozen_string_literal: true

require_relative "helper"
require_relative "support/tree_manager_behavior"
require "active_model/attribute"

module Arel
  class DeleteManagerTest < Arel::Test
    include TreeManagerBehavior

    test "handles limit properly" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.take 10
      dm.from table
      dm.key = table[:id]
      assert_match(/LIMIT 10/, dm.to_sql)
    end

    test "from uses from" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.from table
      assert_like %{ DELETE FROM "users" }, dm.to_sql
    end

    test "from chains" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      assert_equal dm, dm.from(table)
    end

    test "where uses where values" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.from table
      dm.where table[:id].eq(10)
      assert_like %{ DELETE FROM "users" WHERE "users"."id" = 10}, dm.to_sql
    end

    test "where chains" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      assert_equal dm, dm.where(table[:id].eq(10))
    end

    private
      def build_manager(table = nil)
        Arel::DeleteManager.new(table)
      end
  end
end
