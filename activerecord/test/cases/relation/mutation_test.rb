require 'cases/helper'
require 'models/post'

module ActiveRecord
  class RelationMutationTest < ActiveSupport::TestCase
    class FakeKlass < Struct.new(:table_name, :name)
      extend ActiveRecord::Delegation::DelegateCache
      inherited self

      def connection
        Post.connection
      end

      def relation_delegate_class(klass)
        self.class.relation_delegate_class(klass)
      end

      def attribute_alias?(name)
        false
      end

      def sanitize_sql(sql)
        sql
      end
    end

    def relation
      @relation ||= Relation.new FakeKlass.new('posts'), Post.arel_table
    end

    (Relation::MULTI_VALUE_METHODS - [:references, :extending, :order, :unscope, :select]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal [:foo], relation.public_send("#{method}_values")
      end
    end

    test "#_select!" do
      assert relation.public_send("_select!", :foo).equal?(relation)
      assert_equal [:foo], relation.public_send("select_values")
    end

    test '#order!' do
      assert relation.order!('name ASC').equal?(relation)
      assert_equal ['name ASC'], relation.order_values
    end

    test '#order! with symbol prepends the table name' do
      assert relation.order!(:name).equal?(relation)
      node = relation.order_values.first
      assert node.ascending?
      assert_equal :name, node.expr.name
      assert_equal "posts", node.expr.relation.name
    end

    test '#order! on non-string does not attempt regexp match for references' do
      obj = Object.new
      obj.expects(:=~).never
      assert relation.order!(obj)
      assert_equal [obj], relation.order_values
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
      order_relation = self.relation.order('foo')

      assert order_relation.reorder!('bar').equal?(order_relation)
      assert_equal ['bar'], order_relation.order_values
      assert order_relation.reordering_value
    end

    test '#reorder! with symbol prepends the table name' do
      assert relation.reorder!(:name).equal?(relation)
      node = relation.order_values.first

      assert node.ascending?
      assert_equal :name, node.expr.name
      assert_equal "posts", node.expr.relation.name
    end

    test 'reverse_order!' do
      order_relation = Post.order('title ASC, comments_count DESC')

      order_relation.reverse_order!

      assert_equal 'title DESC', order_relation.order_values.first
      assert_equal 'comments_count ASC', order_relation.order_values.last


      order_relation.reverse_order!

      assert_equal 'title ASC', order_relation.order_values.first
      assert_equal 'comments_count DESC', order_relation.order_values.last
    end

    test 'create_with!' do
      assert relation.create_with!(foo: 'bar').equal?(relation)
      assert_equal({foo: 'bar'}, relation.create_with_value)
    end

    test 'test_merge!' do
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

    test 'distinct!' do
      relation.distinct! :foo
      assert_equal :foo, relation.distinct_value
      assert_equal :foo, relation.uniq_value # deprecated access
    end

    test 'uniq! was replaced by distinct!' do
      relation.uniq! :foo
      assert_equal :foo, relation.distinct_value
      assert_equal :foo, relation.uniq_value # deprecated access
    end
  end
end
