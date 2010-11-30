require "cases/helper"

module ActiveRecord
  class RelationTest < ActiveRecord::TestCase
    class FakeTable < Struct.new(:table_name)
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
      assert_equal [:limit, :offset, :lock, :readonly, :create_with, :from].sort,
        Relation::SINGLE_VALUE_METHODS.sort
    end

    def test_initialize_single_values
      relation = Relation.new :a, :b
      Relation::SINGLE_VALUE_METHODS.each do |method|
        assert_nil relation.send("#{method}_value"), method.to_s
      end
    end

    def test_association_methods
      assert_equal [:includes, :eager_load, :preload].sort,
        Relation::ASSOCIATION_METHODS.sort
    end

    def test_initialize_association_methods
      relation = Relation.new :a, :b
      Relation::ASSOCIATION_METHODS.each do |method|
        assert_equal [], relation.send("#{method}_values"), method.to_s
      end
    end

    def test_multi_value_methods
      assert_equal [:select, :group, :order, :joins, :where, :having, :bind].sort,
        Relation::MULTI_VALUE_METHODS.sort
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

    def test_where_values_hash
      relation = Relation.new :a, :b
      assert_equal({}, relation.where_values_hash)

      relation.where_values << :hello
      assert_equal({}, relation.where_values_hash)
    end

    def test_table_name_delegates_to_klass
      relation = Relation.new FakeTable.new('foo'), :b
      assert_equal 'foo', relation.table_name
    end

    def test_scope_for_create
      relation = Relation.new :a, :b
      assert_equal({}, relation.scope_for_create)
    end
  end
end
