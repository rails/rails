# frozen_string_literal: true

require_relative "helper"

module Arel
  class TableTest < Arel::Spec
    before do
      @relation = Table.new(:users)
    end

    it "should create join nodes" do
      join = @relation.create_join "foo", "bar"
      assert_kind_of Arel::Nodes::InnerJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with a klass" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::FullOuterJoin
      assert_kind_of Arel::Nodes::FullOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with a klass" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::OuterJoin
      assert_kind_of Arel::Nodes::OuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    it "should create join nodes with a klass" do
      join = @relation.create_join "foo", "bar", Arel::Nodes::RightOuterJoin
      assert_kind_of Arel::Nodes::RightOuterJoin, join
      assert_equal "foo", join.left
      assert_equal "bar", join.right
    end

    describe "skip" do
      it "should add an offset" do
        sm = @relation.skip 2
        _(sm.to_sql).must_be_like "SELECT FROM \"users\" OFFSET 2"
      end
    end

    describe "having" do
      it "adds a having clause" do
        mgr = @relation.having @relation[:id].eq(10)
        _(mgr.to_sql).must_be_like %{
         SELECT FROM "users" HAVING "users"."id" = 10
        }
      end
    end

    describe "backwards compat" do
      describe "join" do
        it "noops on nil" do
          mgr = @relation.join nil

          _(mgr.to_sql).must_be_like %{ SELECT FROM "users" }
        end

        it "raises EmptyJoinError on empty" do
          assert_raises(EmptyJoinError) do
            @relation.join ""
          end
        end

        it "takes a second argument for join type" do
          right     = @relation.alias
          predicate = @relation[:id].eq(right[:id])
          mgr = @relation.join(right, Nodes::OuterJoin).on(predicate)

          _(mgr.to_sql).must_be_like %{
           SELECT FROM "users"
             LEFT OUTER JOIN "users" "users_2"
               ON "users"."id" = "users_2"."id"
          }
        end
      end

      describe "join" do
        it "creates an outer join" do
          right     = @relation.alias
          predicate = @relation[:id].eq(right[:id])
          mgr = @relation.outer_join(right).on(predicate)

          _(mgr.to_sql).must_be_like %{
            SELECT FROM "users"
              LEFT OUTER JOIN "users" "users_2"
                ON "users"."id" = "users_2"."id"
          }
        end
      end
    end

    describe "group" do
      it "should create a group" do
        manager = @relation.group @relation[:id]
        _(manager.to_sql).must_be_like %{
          SELECT FROM "users" GROUP BY "users"."id"
        }
      end
    end

    describe "alias" do
      it "should create a node that proxies to a table" do
        node = @relation.alias
        _(node.name).must_equal "users_2"
        _(node[:id].relation).must_equal node
      end
    end

    describe "new" do
      it "should accept a hash" do
        rel = Table.new :users, as: "foo"
        _(rel.table_alias).must_equal "foo"
      end

      it "ignores as if it equals name" do
        rel = Table.new :users, as: "users"
        _(rel.table_alias).must_be_nil
      end

      it "should accept literal SQL"  do
        rel = Table.new Arel.sql("generate_series(4, 2)")
        assert_equal Arel.sql("generate_series(4, 2)"), rel.name
      end

      it "should accept Arel nodes"  do
        node = Arel::Nodes::NamedFunction.new("generate_series", [4, 2])
        rel = Table.new node
        assert_equal node, rel.name
      end
    end

    describe "order" do
      it "should take an order" do
        manager = @relation.order "foo"
        _(manager.to_sql).must_be_like %{ SELECT FROM "users" ORDER BY foo }
      end
    end

    describe "take" do
      it "should add a limit" do
        manager = @relation.take 1
        manager.project Nodes::SqlLiteral.new "*"
        _(manager.to_sql).must_be_like %{ SELECT * FROM "users" LIMIT 1 }
      end
    end

    describe "project" do
      it "can project" do
        manager = @relation.project Nodes::SqlLiteral.new "*"
        _(manager.to_sql).must_be_like %{ SELECT * FROM "users" }
      end

      it "takes multiple parameters" do
        manager = @relation.project Nodes::SqlLiteral.new("*"), Nodes::SqlLiteral.new("*")
        _(manager.to_sql).must_be_like %{ SELECT *, * FROM "users" }
      end
    end

    describe "where" do
      it "returns a tree manager" do
        manager = @relation.where @relation[:id].eq 1
        manager.project @relation[:id]
        _(manager).must_be_kind_of TreeManager
        _(manager.to_sql).must_be_like %{
          SELECT "users"."id"
          FROM "users"
          WHERE "users"."id" = 1
        }
      end
    end

    it "should have a name" do
      _(@relation.name).must_equal "users"
    end

    describe "[]" do
      describe "when given a Symbol" do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          column = @relation[:id]
          _(column.name).must_equal "id"
        end
      end
    end

    describe "equality" do
      it "is equal with equal ivars" do
        relation1 = Table.new(:users, as: "zomg")
        relation2 = Table.new(:users, as: "zomg")
        array = [relation1, relation2]
        assert_equal 1, array.uniq.size
      end

      it "is not equal with different ivars" do
        relation1 = Table.new(:users, as: "zomg")
        relation2 = Table.new(:users, as: "zomg2")
        array = [relation1, relation2]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
