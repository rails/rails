# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  class WhereChainTest < ActiveRecord::TestCase
    fixtures :posts

    def setup
      super
      @name = "title"
    end

    def test_not_inverts_where_clause
      relation = Post.where.not(title: "hello")
      expected_where_clause = Post.where(title: "hello").where_clause.invert

      assert_equal expected_where_clause, relation.where_clause
    end

    def test_not_with_nil
      assert_raise ArgumentError do
        Post.where.not(nil)
      end
    end

    def test_association_not_eq
      expected = Comment.arel_table[@name].not_eq(Arel::Nodes::BindParam.new(1))
      relation = Post.joins(:comments).where.not(comments: { title: "hello" })
      assert_equal(expected.to_sql, relation.where_clause.ast.to_sql)
    end

    def test_not_eq_with_preceding_where
      relation = Post.where(title: "hello").where.not(title: "world")
      expected_where_clause =
        Post.where(title: "hello").where_clause +
        Post.where(title: "world").where_clause.invert

      assert_equal expected_where_clause, relation.where_clause
    end

    def test_not_eq_with_succeeding_where
      relation = Post.where.not(title: "hello").where(title: "world")
      expected_where_clause =
        Post.where(title: "hello").where_clause.invert +
        Post.where(title: "world").where_clause

      assert_equal expected_where_clause, relation.where_clause
    end

    def test_chaining_multiple
      relation = Post.where.not(author_id: [1, 2]).where.not(title: "ruby on rails")
      expected_where_clause =
        Post.where(author_id: [1, 2]).where_clause.invert +
        Post.where(title: "ruby on rails").where_clause.invert

      assert_equal expected_where_clause, relation.where_clause
    end

    def test_rewhere_with_one_condition
      relation = Post.where(title: "hello").where(title: "world").rewhere(title: "alone")
      expected = Post.where(title: "alone")

      assert_equal expected.where_clause, relation.where_clause
    end

    def test_rewhere_with_multiple_overwriting_conditions
      relation = Post.where(title: "hello").where(body: "world").rewhere(title: "alone", body: "again")
      expected = Post.where(title: "alone", body: "again")

      assert_equal expected.where_clause, relation.where_clause
    end

    def test_rewhere_with_one_overwriting_condition_and_one_unrelated
      relation = Post.where(title: "hello").where(body: "world").rewhere(title: "alone")
      expected = Post.where(body: "world", title: "alone")

      assert_equal expected.where_clause, relation.where_clause
    end

    def test_rewhere_with_range
      relation = Post.where(comments_count: 1..3).rewhere(comments_count: 3..5)

      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_upper_bound_range
      relation = Post.where(comments_count: 1..Float::INFINITY).rewhere(comments_count: 3..5)

      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_lower_bound_range
      relation = Post.where(comments_count: -Float::INFINITY..1).rewhere(comments_count: 3..5)

      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_range
      relation = Post.where(comments_count: -Float::INFINITY..Float::INFINITY).rewhere(comments_count: 3..5)

      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_exists_with_relation
      relation = Post.where.exists(Comment.where("posts.id = comments.post_id"))
      post = Post.first
      Comment.create!(post: post, body: "Nice!")
      assert_equal [post], relation
    end

    def test_exists_with_string
      relation = Post.where.exists("select * from comments c where posts.id = c.post_id")
      post = Post.first
      Comment.create!(post: post, body: "Nice!")
      assert_equal [post], relation
    end

    def test_not_exists_with_relation
      relation = Post.where.not_exists(Comment.where("posts.id = comments.post_id"))
      post = Post.first
      Comment.create!(post: post, body: "Nice!")
      assert_equal Post.offset(1).to_a, relation
    end

    def test_not_exists_with_string
      relation = Post.where.not_exists("select * from comments c where posts.id = c.post_id")
      post = Post.first
      Comment.create!(post: post, body: "Nice!")
      assert_equal Post.offset(1).to_a, relation
    end
  end
end
