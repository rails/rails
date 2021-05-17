# frozen_string_literal: true

require "cases/helper"
require "models/developer"
require "models/comment"
require "models/post"
require "models/topic"

class NullRelationTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_none
    assert_no_queries do
      assert_equal [], Developer.none
      assert_equal [], Developer.all.none
    end
  end

  def test_none_chainable
    assert_queries(0) do
      assert_equal [], Developer.none.where(name: "David")
    end
  end

  def test_none_chainable_to_existing_scope_extension_method
    assert_no_queries do
      assert_equal 1, Topic.anonymous_extension.none.one
    end
  end

  def test_async_query_on_null_relation
    assert_no_queries do
      assert_equal [], Developer.none.load_async.load
    end
  end

  def test_none_chained_to_methods_firing_queries_straight_to_db
    assert_no_queries do
      assert_equal [],    Developer.none.pluck(:id, :name)
      assert_equal 0,     Developer.none.delete_all
      assert_equal 0,     Developer.none.update_all(name: "David")
      assert_equal 0,     Developer.none.delete(1)
      assert_equal false, Developer.none.exists?(1)
    end
  end

  def test_null_relation_content_size_methods
    assert_no_queries do
      assert_equal 0,     Developer.none.size
      assert_equal 0,     Developer.none.count
      assert_equal true,  Developer.none.empty?
      assert_equal true,  Developer.none.none?
      assert_equal false, Developer.none.any?
      assert_equal false, Developer.none.one?
      assert_equal false, Developer.none.many?
    end
  end

  def test_null_relation_metadata_methods
    assert_includes Developer.none.to_sql, " WHERE (1=0)"
    assert_equal({}, Developer.none.where_values_hash)
  end

  def test_null_relation_where_values_hash
    assert_equal({ "salary" => 100_000 }, Developer.none.where(salary: 100_000).where_values_hash)
  end

  [:count, :sum].each do |method|
    define_method "test_null_relation_#{method}" do
      assert_no_queries do
        assert_equal 0, Comment.none.public_send(method, :id)
        assert_equal Hash.new, Comment.none.group(:post_id).public_send(method, :id)
      end
    end
  end

  [:average, :minimum, :maximum].each do |method|
    define_method "test_null_relation_#{method}" do
      assert_no_queries do
        assert_nil Comment.none.public_send(method, :id)
        assert_equal Hash.new, Comment.none.group(:post_id).public_send(method, :id)
      end
    end
  end

  def test_null_relation_in_where_condition
    assert_operator Comment.count, :>, 0 # precondition, make sure there are comments.
    assert_equal 0, Comment.where(post_id: Post.none).count
  end
end
