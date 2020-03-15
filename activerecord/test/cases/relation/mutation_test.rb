# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  class RelationMutationTest < ActiveRecord::TestCase
    (Relation::MULTI_VALUE_METHODS - [:references, :extending, :order, :unscope, :select]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal [:foo], relation.public_send("#{method}_values")
      end
    end

    test "#_select!" do
      assert relation._select!(:foo).equal?(relation)
      assert_equal [:foo], relation.select_values
    end

    test "#order!" do
      assert relation.order!("name ASC").equal?(relation)
      assert_equal ["name ASC"], relation.order_values
    end

    test "#order! with symbol prepends the table name" do
      assert relation.order!(:name).equal?(relation)
      node = relation.order_values.first
      assert_predicate node, :ascending?
      assert_equal "name", node.expr.name
      assert_equal "posts", node.expr.relation.name
    end

    test "#order! on non-string does not attempt regexp match for references" do
      obj = Object.new
      assert_not_called(obj, :=~) do
        assert relation.order!(obj)
        assert_equal [obj], relation.order_values
      end
    end

    test "#references!" do
      assert relation.references!(:foo).equal?(relation)
      assert_includes relation.references_values, "foo"
    end

    test "extending!" do
      mod, mod2 = Module.new, Module.new

      assert relation.extending!(mod).equal?(relation)
      assert_equal [mod], relation.extending_values
      assert relation.is_a?(mod)

      relation.extending!(mod2)
      assert_equal [mod, mod2], relation.extending_values
    end

    test "extending! with empty args" do
      relation.extending!
      assert_equal [], relation.extending_values
    end

    (Relation::SINGLE_VALUE_METHODS - [:lock, :reordering, :reverse_order, :create_with, :skip_query_cache, :strict_loading]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal :foo, relation.public_send("#{method}_value")
      end
    end

    test "#from!" do
      assert relation.from!("foo").equal?(relation)
      assert_equal "foo", relation.from_clause.value
    end

    test "#lock!" do
      assert relation.lock!("foo").equal?(relation)
      assert_equal "foo", relation.lock_value
    end

    test "#reorder!" do
      @relation = relation.order("foo")

      assert relation.reorder!("bar").equal?(relation)
      assert_equal ["bar"], relation.order_values
      assert relation.reordering_value
    end

    test "#reorder! with symbol prepends the table name" do
      assert relation.reorder!(:name).equal?(relation)
      node = relation.order_values.first

      assert_predicate node, :ascending?
      assert_equal "name", node.expr.name
      assert_equal "posts", node.expr.relation.name
    end

    test "reverse_order!" do
      @relation = Post.order("title ASC, comments_count DESC")

      relation.reverse_order!

      assert_equal "title DESC", relation.order_values.first
      assert_equal "comments_count ASC", relation.order_values.last

      relation.reverse_order!

      assert_equal "title ASC", relation.order_values.first
      assert_equal "comments_count DESC", relation.order_values.last
    end

    test "create_with!" do
      assert relation.create_with!(foo: "bar").equal?(relation)
      assert_equal({ foo: "bar" }, relation.create_with_value)
    end

    test "merge!" do
      assert relation.merge!(select: :foo).equal?(relation)
      assert_equal [:foo], relation.select_values
    end

    test "merge with a proc" do
      assert_equal [:foo], relation.merge(-> { select(:foo) }).select_values
    end

    test "none!" do
      assert relation.none!.equal?(relation)
      assert_equal [NullRelation], relation.extending_values
      assert relation.is_a?(NullRelation)
    end

    test "distinct!" do
      relation.distinct! :foo
      assert_equal :foo, relation.distinct_value
    end

    test "skip_query_cache!" do
      relation.skip_query_cache!
      assert relation.skip_query_cache_value
    end

    test "skip_preloading!" do
      relation.skip_preloading!
      assert relation.skip_preloading_value
    end

    private
      def relation
        @relation ||= Relation.new(FakeKlass)
      end
  end
end
