require 'cases/helper'
require 'models/post'
require 'models/comment'

module ActiveRecord
  class WhereChainTest < ActiveRecord::TestCase
    fixtures :posts

    def test_not_eq
      expected = Arel::Nodes::NotEqual.new(Post.arel_table[:title], 'hello')
      relation = Post.where.not(title: 'hello')
      assert_equal([expected], relation.where_values)
    end

    def test_not_null
      expected = Arel::Nodes::NotEqual.new(Post.arel_table[:title], nil)
      relation = Post.where.not(title: nil)
      assert_equal([expected], relation.where_values)
    end

    def test_not_in
      expected = Arel::Nodes::NotIn.new(Post.arel_table[:title], %w[hello goodbye])
      relation = Post.where.not(title: %w[hello goodbye])
      assert_equal([expected], relation.where_values)
    end

    def test_association_not_eq
      expected = Arel::Nodes::NotEqual.new(Comment.arel_table[:title], 'hello')
      relation = Post.joins(:comments).where.not(comments: {title: 'hello'})
      assert_equal(expected.to_sql, relation.where_values.first.to_sql)
    end

    def test_not_eq_with_preceding_where
      relation = Post.where(title: 'hello').where.not(title: 'world')

      expected = Arel::Nodes::Equality.new(Post.arel_table[:title], 'hello')
      assert_equal(expected, relation.where_values.first)

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[:title], 'world')
      assert_equal(expected, relation.where_values.last)
    end

    def test_not_eq_with_succeeding_where
      relation = Post.where.not(title: 'hello').where(title: 'world')

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[:title], 'hello')
      assert_equal(expected, relation.where_values.first)

      expected = Arel::Nodes::Equality.new(Post.arel_table[:title], 'world')
      assert_equal(expected, relation.where_values.last)
    end

    def test_not_eq_with_string_parameter
      expected = Arel::Nodes::Not.new("title = 'hello'")
      relation = Post.where.not("title = 'hello'")
      assert_equal([expected], relation.where_values)
    end

    def test_not_eq_with_array_parameter
      expected = Arel::Nodes::Not.new("title = 'hello'")
      relation = Post.where.not(['title = ?', 'hello'])
      assert_equal([expected], relation.where_values)
    end

    def test_like
      expected = Arel::Nodes::Matches.new(Post.arel_table[:title], 'a%')
      relation = Post.where.like(title: 'a%')
      assert_equal([expected], relation.where_values)
    end

    def test_not_like
      expected = Arel::Nodes::DoesNotMatch.new(Post.arel_table[:title], 'a%')
      relation = Post.where.not_like(title: 'a%')
      assert_equal([expected], relation.where_values)
    end

    def test_greater_than
      expected = Arel::Nodes::GreaterThan.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.greater_than(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_gt
      expected = Arel::Nodes::GreaterThan.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.gt(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end


    def test_greater_than_or_equal
      expected = Arel::Nodes::GreaterThanOrEqual.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.greater_than_or_equal(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_gte
      expected = Arel::Nodes::GreaterThanOrEqual.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.gte(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_less_than
      expected = Arel::Nodes::LessThan.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.less_than(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_lt
      expected = Arel::Nodes::LessThan.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.lt(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_less_than_or_equal
      expected = Arel::Nodes::LessThanOrEqual.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.less_than_or_equal(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_lte
      expected = Arel::Nodes::LessThanOrEqual.new(Post.arel_table[:comments_count], 1)
      relation = Post.where.lte(comments_count: 1)
      assert_equal([expected], relation.where_values)
    end

    def test_chaining_multiple
      relation = Post.where.like(title: 'ruby on %').where.not(title: 'ruby on rails').where.not_like(title: '% ales')

      expected = Arel::Nodes::Matches.new(Post.arel_table[:title], 'ruby on %')
      assert_equal(expected, relation.where_values[0])

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[:title], 'ruby on rails')
      assert_equal(expected, relation.where_values[1])

      expected = Arel::Nodes::DoesNotMatch.new(Post.arel_table[:title], '% ales')
      assert_equal(expected, relation.where_values[2])
    end
  end
end
