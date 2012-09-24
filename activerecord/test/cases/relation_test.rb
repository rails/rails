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

    def test_responds_to_model_and_returns_klass
      relation = Relation.new :a, :b
      assert_equal :a, relation.model
    end

    def test_initialize_single_values
      relation = Relation.new :a, :b
      (Relation::SINGLE_VALUE_METHODS - [:create_with]).each do |method|
        assert_nil relation.send("#{method}_value"), method.to_s
      end
      assert_equal({}, relation.create_with_value)
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

      relation.where! :hello
      assert_equal({}, relation.where_values_hash)
    end

    def test_has_values
      relation = Relation.new Post, Post.arel_table
      relation.where! relation.table[:id].eq(10)
      assert_equal({:id => 10}, relation.where_values_hash)
    end

    def test_values_wrong_table
      relation = Relation.new Post, Post.arel_table
      relation.where! Comment.arel_table[:id].eq(10)
      assert_equal({}, relation.where_values_hash)
    end

    def test_tree_is_not_traversed
      relation = Relation.new Post, Post.arel_table
      left     = relation.table[:id].eq(10)
      right    = relation.table[:id].eq(10)
      combine  = left.and right
      relation.where! combine
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
      relation.where! relation.table[:id].eq(10)
      relation.create_with_value = {:hello => 'world'}
      assert_equal({:hello => 'world', :id => 10}, relation.scope_for_create)
    end

    # FIXME: is this really wanted or expected behavior?
    def test_scope_for_create_is_cached
      relation = Relation.new Post, Post.arel_table
      assert_equal({}, relation.scope_for_create)

      relation.where! relation.table[:id].eq(10)
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
      relation.eager_load! :b
      assert relation.eager_loading?
    end

    def test_references_values
      relation = Relation.new :a, :b
      assert_equal [], relation.references_values
      relation = relation.references(:foo).references(:omg, :lol)
      assert_equal ['foo', 'omg', 'lol'], relation.references_values
    end

    def test_references_values_dont_duplicate
      relation = Relation.new :a, :b
      relation = relation.references(:foo).references(:foo)
      assert_equal ['foo'], relation.references_values
    end

    test 'merging a hash into a relation' do
      relation = Relation.new :a, :b
      relation = relation.merge where: :lol, readonly: true

      assert_equal [:lol], relation.where_values
      assert_equal true, relation.readonly_value
    end

    test 'merging an empty hash into a relation' do
      assert_equal [], Relation.new(:a, :b).merge({}).where_values
    end

    test 'merging a hash with unknown keys raises' do
      assert_raises(ArgumentError) { Relation::HashMerger.new(nil, omg: 'lol') }
    end

    test '#values returns a dup of the values' do
      relation = Relation.new(:a, :b).where! :foo
      values   = relation.values

      values[:where] = nil
      assert_not_nil relation.where_values
    end

    test 'relations can be created with a values hash' do
      relation = Relation.new(:a, :b, where: [:foo])
      assert_equal [:foo], relation.where_values
    end

    test 'merging a single where value' do
      relation = Relation.new(:a, :b)
      relation.merge!(where: :foo)
      assert_equal [:foo], relation.where_values
    end

    test 'merging a hash interpolates conditions' do
      klass = stub
      klass.stubs(:sanitize_sql).with(['foo = ?', 'bar']).returns('foo = bar')

      relation = Relation.new(klass, :b)
      relation.merge!(where: ['foo = ?', 'bar'])
      assert_equal ['foo = bar'], relation.where_values
    end
  end

  class RelationMutationTest < ActiveSupport::TestCase
    def relation
      @relation ||= Relation.new :a, :b
    end

    (Relation::MULTI_VALUE_METHODS - [:references, :extending]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal [:foo], relation.public_send("#{method}_values")
      end
    end

    test '#references!' do
      assert relation.references!(:foo).equal?(relation)
      assert relation.references_values.include?('foo')
    end

    test 'extending!' do
      mod, mod2 = Module.new, Module.new

      assert relation.extending!(mod).equal?(relation)
      assert_equal [mod], relation.extending_values
      assert relation.is_a?(mod)

      relation.extending!(mod2)
      assert_equal [mod, mod2], relation.extending_values
    end

    test 'extending! with empty args' do
      relation.extending!
      assert_equal [], relation.extending_values
    end

    (Relation::SINGLE_VALUE_METHODS - [:from, :lock, :reordering, :reverse_order, :create_with]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal :foo, relation.public_send("#{method}_value")
      end
    end

    test '#from!' do
      assert relation.from!('foo').equal?(relation)
      assert_equal ['foo', nil], relation.from_value
    end

    test '#lock!' do
      assert relation.lock!('foo').equal?(relation)
      assert_equal 'foo', relation.lock_value
    end

    test '#reorder!' do
      relation = self.relation.order('foo')

      assert relation.reorder!('bar').equal?(relation)
      assert_equal ['bar'], relation.order_values
      assert relation.reordering_value
    end

    test 'reverse_order!' do
      assert relation.reverse_order!.equal?(relation)
      assert relation.reverse_order_value
      relation.reverse_order!
      assert !relation.reverse_order_value
    end

    test 'create_with!' do
      assert relation.create_with!(foo: 'bar').equal?(relation)
      assert_equal({foo: 'bar'}, relation.create_with_value)
    end

    test 'merge!' do
      assert relation.merge!(where: :foo).equal?(relation)
      assert_equal [:foo], relation.where_values
    end

    test 'merge with a proc' do
      assert_equal [:foo], relation.merge(-> { where(:foo) }).where_values
    end

    test 'none!' do
      assert relation.none!.equal?(relation)
      assert_equal [NullRelation], relation.extending_values
      assert relation.is_a?(NullRelation)
    end
  end
end
