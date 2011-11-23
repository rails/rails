require "cases/helper"
require 'models/post'
require 'models/comment'

module ActiveRecord
  class RelationTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    class FakeKlass < Struct.new(:table_name)
    end

    def test_construction
      relation = nil
      assert_nothing_raised do
        relation = Relation.new :a, :b
      end
      assert_equal :a, relation.klass
      assert_equal :b, relation.table
      assert !relation.loaded, 'relation is not loaded'
    end

    def test_single_values
      assert_equal [:limit, :offset, :lock, :readonly, :from, :reorder, :reverse_order, :uniq].map(&:to_s).sort,
        Relation::SINGLE_VALUE_METHODS.map(&:to_s).sort
    end

    def test_initialize_single_values
      relation = Relation.new :a, :b
      Relation::SINGLE_VALUE_METHODS.each do |method|
        assert_nil relation.send("#{method}_value"), method.to_s
      end
    end

    def test_association_methods
      assert_equal [:includes, :eager_load, :preload].map(&:to_s).sort,
        Relation::ASSOCIATION_METHODS.map(&:to_s).sort
    end

    def test_initialize_association_methods
      relation = Relation.new :a, :b
      Relation::ASSOCIATION_METHODS.each do |method|
        assert_equal [], relation.send("#{method}_values"), method.to_s
      end
    end

    def test_multi_value_methods
      assert_equal [:select, :group, :order, :joins, :where, :having, :bind].map(&:to_s).sort,
        Relation::MULTI_VALUE_METHODS.map(&:to_s).sort
    end

    def test_multi_value_initialize
      relation = Relation.new :a, :b
      Relation::MULTI_VALUE_METHODS.each do |method|
        assert_equal [], relation.send("#{method}_values"), method.to_s
      end
    end

    def test_extensions
      relation = Relation.new :a, :b
      assert_equal [], relation.extensions
    end

    def test_empty_where_values_hash
      relation = Relation.new :a, :b
      assert_equal({}, relation.where_values_hash)

      relation.where_values << :hello
      assert_equal({}, relation.where_values_hash)
    end

    def test_has_values
      relation = Relation.new Post, Post.arel_table
      relation.where_values << relation.table[:id].eq(10)
      assert_equal({:id => 10}, relation.where_values_hash)
    end

    def test_values_wrong_table
      relation = Relation.new Post, Post.arel_table
      relation.where_values << Comment.arel_table[:id].eq(10)
      assert_equal({}, relation.where_values_hash)
    end

    def test_tree_is_not_traversed
      relation = Relation.new Post, Post.arel_table
      left     = relation.table[:id].eq(10)
      right    = relation.table[:id].eq(10)
      combine  = left.and right
      relation.where_values << combine
      assert_equal({}, relation.where_values_hash)
    end

    def test_table_name_delegates_to_klass
      relation = Relation.new FakeKlass.new('foo'), :b
      assert_equal 'foo', relation.table_name
    end

    def test_scope_for_create
      relation = Relation.new :a, :b
      assert_equal({}, relation.scope_for_create)
    end

    def test_create_with_value
      relation = Relation.new Post, Post.arel_table
      hash = { :hello => 'world' }
      relation.create_with_value = hash
      assert_equal hash, relation.scope_for_create
    end

    def test_create_with_value_with_wheres
      relation = Relation.new Post, Post.arel_table
      relation.where_values << relation.table[:id].eq(10)
      relation.create_with_value = {:hello => 'world'}
      assert_equal({:hello => 'world', :id => 10}, relation.scope_for_create)
    end

    # FIXME: is this really wanted or expected behavior?
    def test_scope_for_create_is_cached
      relation = Relation.new Post, Post.arel_table
      assert_equal({}, relation.scope_for_create)

      relation.where_values << relation.table[:id].eq(10)
      assert_equal({}, relation.scope_for_create)

      relation.create_with_value = {:hello => 'world'}
      assert_equal({}, relation.scope_for_create)
    end

    def test_empty_eager_loading?
      relation = Relation.new :a, :b
      assert !relation.eager_loading?
    end

    def test_eager_load_values
      relation = Relation.new :a, :b
      relation.eager_load_values << :b
      assert relation.eager_loading?
    end
  end
end
