# frozen_string_literal: true

require_relative "helper"

module Arel
  class DeleteManagerTest < Arel::Spec
    it "handles limit properly" do
      table = Table.new(:users)
      dm = Arel::DeleteManager.new
      dm.take 10
      dm.from table
      dm.key = table[:id]
      assert_match(/LIMIT 10/, dm.to_sql)
    end

    describe "from" do
      it "uses from" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        dm.from table
        _(dm.to_sql).must_be_like %{ DELETE FROM "users" }
      end

      it "chains" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        _(dm.from(table)).must_equal dm
      end
    end

    describe "where" do
      it "uses where values" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        dm.from table
        dm.where table[:id].eq(10)
        _(dm.to_sql).must_be_like %{ DELETE FROM "users" WHERE "users"."id" = 10}
      end

      it "chains" do
        table = Table.new(:users)
        dm = Arel::DeleteManager.new
        _(dm.where(table[:id].eq(10))).must_equal dm
      end
    end

    describe "as" do
      it "makes an AS node by grouping the AST" do
        manager = Arel::DeleteManager.new
        as = manager.as(Arel.sql("foo"))
        assert_kind_of Arel::Nodes::Grouping, as.left
        assert_equal manager.ast, as.left.expr
        assert_equal "foo", as.right
      end

      it "converts right to SqlLiteral if a string" do
        manager = Arel::DeleteManager.new
        as = manager.as("foo")
        assert_kind_of Arel::Nodes::SqlLiteral, as.right
      end

      it "converts right to SqlLiteral if a symbol" do
        manager = Arel::DeleteManager.new
        as = manager.as(:foo)
        assert_kind_of Arel::Nodes::SqlLiteral, as.right
      end

      it "can make a subselect" do
        manager = Arel::DeleteManager.new
        manager.from Arel.sql("zomg")
        as = manager.as(Arel.sql("foo"))

        manager = Arel::SelectManager.new
        manager.project Arel.sql("name")
        manager.from as
        _(manager.to_sql).must_be_like "SELECT name FROM (DELETE FROM zomg) foo"
      end
    end
  end
end
