require 'cases/helper'
require 'models/post'
require 'models/comment'
require 'models/tag'
require 'models/tagging'

module ActiveRecord
  class RelationMutationTest < ActiveSupport::TestCase
    fixtures :posts, :comments, :tags, :taggings

    class TopicWithCallbacks < ActiveRecord::Base
      self.table_name = :topics
      before_update { |topic| topic.author_name = 'David' if topic.author_name.blank? }
    end

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
      @relation ||= Relation.new FakeKlass.new('posts'), Post.arel_table, Post.predicate_builder
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

    (Relation::SINGLE_VALUE_METHODS - [:lock, :reordering, :reverse_order, :create_with]).each do |method|
      test "##{method}!" do
        assert relation.public_send("#{method}!", :foo).equal?(relation)
        assert_equal :foo, relation.public_send("#{method}_value")
      end
    end

    test '#from!' do
      assert relation.from!('foo').equal?(relation)
      assert_equal 'foo', relation.from_clause.value
    end

    test '#lock!' do
      assert relation.lock!('foo').equal?(relation)
      assert_equal 'foo', relation.lock_value
    end

    test '#reorder!' do
      @relation = self.relation.order('foo')

      assert relation.reorder!('bar').equal?(relation)
      assert_equal ['bar'], relation.order_values
      assert relation.reordering_value
    end

    test '#reorder! with symbol prepends the table name' do
      assert relation.reorder!(:name).equal?(relation)
      node = relation.order_values.first

      assert node.ascending?
      assert_equal :name, node.expr.name
      assert_equal "posts", node.expr.relation.name
    end

    test 'reverse_order!' do
      @relation = Post.order('title ASC, comments_count DESC')

      relation.reverse_order!

      assert_equal 'title DESC', relation.order_values.first
      assert_equal 'comments_count ASC', relation.order_values.last


      relation.reverse_order!

      assert_equal 'title ASC', relation.order_values.first
      assert_equal 'comments_count DESC', relation.order_values.last
    end

    test 'create_with!' do
      assert relation.create_with!(foo: 'bar').equal?(relation)
      assert_equal({foo: 'bar'}, relation.create_with_value)
    end

    test 'test_merge!' do
      assert relation.merge!(select: :foo).equal?(relation)
      assert_equal [:foo], relation.select_values
    end

    test 'merge with a proc' do
      assert_equal [:foo], relation.merge(-> { select(:foo) }).select_values
    end

    test 'none!' do
      assert relation.none!.equal?(relation)
      assert relation.null?
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

    def test_update_all_with_scope
      tag = Tag.first
      Post.tagged_with(tag.id).update_all title: "rofl"
      list = Post.tagged_with(tag.id).all.to_a
      assert_operator list.length, :>, 0
      list.each { |post| assert_equal 'rofl', post.title }
    end

    def test_update_all_with_blank_argument
      assert_raises(ArgumentError) { Comment.update_all({}) }
    end

    def test_update_all_with_joins
      comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id)
      count    = comments.count

      assert_equal count, comments.update_all(:post_id => posts(:thinking).id)
      assert_equal posts(:thinking), comments(:greetings).post
    end

    def test_update_all_with_joins_and_limit
      comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).limit(1)
      assert_equal 1, comments.update_all(:post_id => posts(:thinking).id)
    end

    def test_update_all_with_joins_and_limit_and_order
      comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).order('comments.id').limit(1)
      assert_equal 1, comments.update_all(:post_id => posts(:thinking).id)
      assert_equal posts(:thinking), comments(:greetings).post
      assert_equal posts(:welcome),  comments(:more_greetings).post
    end

    def test_update_all_with_joins_and_offset
      all_comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id)
      count        = all_comments.count
      comments     = all_comments.offset(1)

      assert_equal count - 1, comments.update_all(:post_id => posts(:thinking).id)
    end

    def test_update_all_with_joins_and_offset_and_order
      all_comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).order('posts.id', 'comments.id')
      count        = all_comments.count
      comments     = all_comments.offset(1)

      assert_equal count - 1, comments.update_all(:post_id => posts(:thinking).id)
      assert_equal posts(:thinking), comments(:more_greetings).post
      assert_equal posts(:welcome),  comments(:greetings).post
    end

    def test_update_on_relation
      topic1 = TopicWithCallbacks.create! title: 'arel', author_name: nil
      topic2 = TopicWithCallbacks.create! title: 'activerecord', author_name: nil
      topics = TopicWithCallbacks.where(id: [topic1.id, topic2.id])
      topics.update(title: 'adequaterecord')

      assert_equal 'adequaterecord', topic1.reload.title
      assert_equal 'adequaterecord', topic2.reload.title
      # Testing that the before_update callbacks have run
      assert_equal 'David', topic1.reload.author_name
      assert_equal 'David', topic2.reload.author_name
    end

    class EnsureRoundTripTypeCasting < ActiveRecord::Type::Value
      def type
        :string
      end

      def deserialize(value)
        raise value unless value == "type cast for database"
        "type cast from database"
      end

      def serialize(value)
        raise value unless value == "value from user"
        "type cast for database"
      end
    end

    class UpdateAllTestModel < ActiveRecord::Base
      self.table_name = 'posts'

      attribute :body, EnsureRoundTripTypeCasting.new
    end

    def test_update_all_goes_through_normal_type_casting
      UpdateAllTestModel.update_all(body: "value from user", type: nil) # No STI

      assert_equal "type cast from database", UpdateAllTestModel.first.body
    end
  end
end
