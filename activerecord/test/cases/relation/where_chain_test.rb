# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/author"
require "models/human"
require "models/essay"
require "models/comment"
require "models/categorization"

module ActiveRecord
  class WhereChainTest < ActiveRecord::TestCase
    fixtures :posts, :comments, :authors, :humans, :essays

    def test_associated_with_association
      Post.where.associated(:author).tap do |relation|
        assert_includes     relation, posts(:welcome)
        assert_includes     relation, posts(:sti_habtm)
        assert_not_includes relation, posts(:authorless)
      end
    end

    def test_associated_with_multiple_associations
      Post.where.associated(:author, :comments).tap do |relation|
        assert_includes     relation, posts(:welcome)
        assert_not_includes relation, posts(:sti_habtm)
        assert_not_includes relation, posts(:authorless)
      end
    end

    def test_missing_with_association
      assert posts(:authorless).author.blank?
      assert_equal [posts(:authorless)], Post.where.missing(:author).to_a
    end

    def test_missing_with_multiple_association
      assert posts(:authorless).comments.empty?
      assert_equal [posts(:authorless)], Post.where.missing(:author, :comments).to_a
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
      expected = Comment.arel_table["title"].not_eq(Arel::Nodes::BindParam.new(1))
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
      relation = Post.where(body: "hello").where(body: "world").rewhere(body: "hullo")
      expected = Post.where(body: "hullo")

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_multiple_overwriting_conditions
      relation = Post.where(body: "hello").where(type: "StiPost").rewhere(body: "hullo", type: "Post")
      expected = Post.where(body: "hullo", type: "Post")

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_one_overwriting_condition_and_one_unrelated
      relation = Post.where(body: "hello").where(type: "Post").rewhere(body: "hullo")
      expected = Post.where(body: "hullo", type: "Post")

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_alias_condition
      relation = Post.where(text: "hello").where(text: "world").rewhere(text: "hullo")
      expected = Post.where(text: "hullo")

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_nested_condition
      relation = Post.where.missing(:comments).rewhere("comments.id": comments(:does_it_hurt))
      expected = Post.left_joins(:comments).where("comments.id": comments(:does_it_hurt))

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_polymorphic_association
      relation = Essay.where(writer: authors(:david)).rewhere(writer: humans(:steve))
      expected = Essay.where(writer: humans(:steve))

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_range
      relation = Post.where(comments_count: 1..3).rewhere(comments_count: 3..5)
      expected = Post.where(comments_count: 3..5)

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_infinite_upper_bound_range
      relation = Post.where(comments_count: 1..Float::INFINITY).rewhere(comments_count: 3..5)
      expected = Post.where(comments_count: 3..5)

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_infinite_lower_bound_range
      relation = Post.where(comments_count: -Float::INFINITY..1).rewhere(comments_count: 3..5)
      expected = Post.where(comments_count: 3..5)

      assert_equal expected.to_a, relation.to_a
    end

    def test_rewhere_with_infinite_range
      relation = Post.where(comments_count: -Float::INFINITY..Float::INFINITY).rewhere(comments_count: 3..5)
      expected = Post.where(comments_count: 3..5)

      assert_equal expected.to_a, relation.to_a
    end
  end
end
