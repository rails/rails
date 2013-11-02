require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/rating'

module ActiveRecord
  class OrderTest < ActiveRecord::TestCase

    def test_order_with_hash_values_other_than_asc_or_desc
      assert_raises(ArgumentError) do
        Post.order(title: nil).all
      end
    end

    def test_nested_order
      table = Arel::Table.new('comments', Post.arel_engine)
      expected = Arel::Nodes::Ascending.new(table[:body])
      relation = Post.order(comments: { body: :asc })
      assert_equal expected, relation.order_values.first
    end

    def test_deep_nested_order
      table = Arel::Table.new('ratings', Post.arel_engine)
      expected = Arel::Nodes::Ascending.new(table[:value])
      relation = Post.order(comments: { ratings: { value: :asc }})
      assert_equal expected, relation.order_values.first
    end

    def test_order_chaining_multiple
      relation = Post.order(comments: { id: :desc, body: :asc }).order(:title)
      expected = Arel::Nodes::Ascending.new(Post.arel_table[:title])
      assert_equal expected, relation.order_values[2]
    end

    def test_nested_order_error
      assert_raises(ActiveRecord::StatementInvalid) do
        Post.order(:comments => { 'posts.author_id' => :asc }).first
      end
    end

    def test_nested_order_with_hash_values_other_than_asc_or_desc
      assert_raises(ArgumentError) do
        Post.order(comments: { body: [] }).all
      end
    end

  end
end
