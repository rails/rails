require 'cases/helper'
require 'models/post'
require 'models/comment'

module ActiveRecord
  class WhereChainTest < ActiveRecord::TestCase
    fixtures :posts

    def setup
      super
      @name = 'title'
    end

    def test_not_eq
      expected = Arel::Nodes::NotEqual.new(Post.arel_table[@name], 'hello')
      relation = Post.where.not(title: 'hello')
      assert_equal([expected], relation.where_values)
    end

    def test_not_null
      expected = Arel::Nodes::NotEqual.new(Post.arel_table[@name], nil)
      relation = Post.where.not(title: nil)
      assert_equal([expected], relation.where_values)
    end

    def test_not_in
      expected = Arel::Nodes::NotIn.new(Post.arel_table[@name], %w[hello goodbye])
      relation = Post.where.not(title: %w[hello goodbye])
      assert_equal([expected], relation.where_values)
    end

    def test_association_not_eq
      expected = Arel::Nodes::NotEqual.new(Comment.arel_table[@name], 'hello')
      relation = Post.joins(:comments).where.not(comments: {title: 'hello'})
      assert_equal(expected.to_sql, relation.where_values.first.to_sql)
    end

    def test_not_eq_with_preceding_where
      relation = Post.where(title: 'hello').where.not(title: 'world')

      expected = Arel::Nodes::Equality.new(Post.arel_table[@name], 'hello')
      assert_equal(expected, relation.where_values.first)

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[@name], 'world')
      assert_equal(expected, relation.where_values.last)
    end

    def test_not_eq_with_succeeding_where
      relation = Post.where.not(title: 'hello').where(title: 'world')

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[@name], 'hello')
      assert_equal(expected, relation.where_values.first)

      expected = Arel::Nodes::Equality.new(Post.arel_table[@name], 'world')
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

    def test_chaining_multiple
      relation = Post.where.not(author_id: [1, 2]).where.not(title: 'ruby on rails')

      expected = Arel::Nodes::NotIn.new(Post.arel_table['author_id'], [1, 2])
      assert_equal(expected, relation.where_values[0])

      expected = Arel::Nodes::NotEqual.new(Post.arel_table[@name], 'ruby on rails')
      assert_equal(expected, relation.where_values[1])
    end

    def test_rewhere_with_one_condition
      relation = Post.where(title: 'hello').where(title: 'world').rewhere(title: 'alone')

      expected = Arel::Nodes::Equality.new(Post.arel_table[@name], 'alone')
      assert_equal 1, relation.where_values.size
      assert_equal expected, relation.where_values.first
    end

    def test_rewhere_with_multiple_overwriting_conditions
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone', body: 'again')

      title_expected = Arel::Nodes::Equality.new(Post.arel_table['title'], 'alone')
      body_expected  = Arel::Nodes::Equality.new(Post.arel_table['body'], 'again')

      assert_equal 2, relation.where_values.size
      assert_equal title_expected, relation.where_values.first
      assert_equal body_expected, relation.where_values.second
    end

    def test_rewhere_with_one_overwriting_condition_and_one_unrelated
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone')

      title_expected = Arel::Nodes::Equality.new(Post.arel_table['title'], 'alone')
      body_expected  = Arel::Nodes::Equality.new(Post.arel_table['body'], 'world')

      assert_equal 2, relation.where_values.size
      assert_equal body_expected, relation.where_values.first
      assert_equal title_expected, relation.where_values.second
    end

    def test_unwhere_with_one_condition
      relation = Post.where(title: 'hello').unwhere(:title)

      assert_equal 0, relation.where_values.size
    end

    def test_unwhere_with_overwriting
      relation = Post.where(title: 'hello').where(body: 'world').unwhere(:title).unwhere(:title, :body)

      assert_equal 0, relation.where_values.size
    end

    def test_unwhere_with_unused_clauses
      relation = Post.where(title: 'hello').unwhere(:body)

      title_expected = Arel::Nodes::Equality.new(Post.arel_table['title'], 'hello')

      assert_equal 1, relation.where_values.size
      assert_equal title_expected, relation.where_values.first
    end

    def test_unwhere_with_multiple_conditions
      relation = Post.where(author_id: 1).where(body: 'world').where(title: 'hello').unwhere(:author_id, :title)

      body_expected  = Arel::Nodes::Equality.new(Post.arel_table['body'], 'world')

      assert_equal 1, relation.where_values.size
      assert_equal body_expected, relation.where_values.first
    end

    def test_unwhere_without_params
      relation = Post.where(author_id: 1).where(body: 'world').where(title: 'hello').unwhere

      assert_equal 0, relation.where_values.size
    end
  end
end
