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
      relation = Post.where.not(title: 'hello')

      assert_equal 1, relation.where_values.length

      value = relation.where_values.first
      bind  = relation.bind_values.first

      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::NotEqual
      assert_equal 'hello', bind.last
    end

    def test_not_null
      expected = Post.arel_table[@name].not_eq(nil)
      relation = Post.where.not(title: nil)
      assert_equal([expected], relation.where_values)
    end

    def test_not_with_nil
      assert_raise ArgumentError do
        Post.where.not(nil)
      end
    end

    def test_not_in
      expected = Post.arel_table[@name].not_in(%w[hello goodbye])
      relation = Post.where.not(title: %w[hello goodbye])
      assert_equal([expected], relation.where_values)
    end

    def test_association_not_eq
      expected = Comment.arel_table[@name].not_eq('hello')
      relation = Post.joins(:comments).where.not(comments: {title: 'hello'})
      assert_equal(expected.to_sql, relation.where_values.first.to_sql)
    end

    def test_not_eq_with_preceding_where
      relation = Post.where(title: 'hello').where.not(title: 'world')

      value = relation.where_values.first
      bind  = relation.bind_values.first
      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::Equality
      assert_equal 'hello', bind.last

      value = relation.where_values.last
      bind  = relation.bind_values.last
      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::NotEqual
      assert_equal 'world', bind.last
    end

    def test_not_eq_with_succeeding_where
      relation = Post.where.not(title: 'hello').where(title: 'world')

      value = relation.where_values.first
      bind  = relation.bind_values.first
      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::NotEqual
      assert_equal 'hello', bind.last

      value = relation.where_values.last
      bind  = relation.bind_values.last
      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::Equality
      assert_equal 'world', bind.last
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

      expected = Post.arel_table['author_id'].not_in([1, 2])
      assert_equal(expected, relation.where_values[0])

      value = relation.where_values[1]
      bind  = relation.bind_values.first

      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::NotEqual
      assert_equal 'ruby on rails', bind.last
    end

    def test_rewhere_with_one_condition
      relation = Post.where(title: 'hello').where(title: 'world').rewhere(title: 'alone')

      assert_equal 1, relation.where_values.size
      value = relation.where_values.first
      bind = relation.bind_values.first
      assert_bound_ast value, Post.arel_table[@name], Arel::Nodes::Equality
      assert_equal 'alone', bind.last
    end

    def test_rewhere_with_multiple_overwriting_conditions
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone', body: 'again')

      assert_equal 2, relation.where_values.size

      value = relation.where_values.first
      bind = relation.bind_values.first
      assert_bound_ast value, Post.arel_table['title'], Arel::Nodes::Equality
      assert_equal 'alone', bind.last

      value = relation.where_values[1]
      bind = relation.bind_values[1]
      assert_bound_ast value, Post.arel_table['body'], Arel::Nodes::Equality
      assert_equal 'again', bind.last
    end

    def assert_bound_ast value, table, type
      assert_equal table, value.left
      assert_kind_of type, value
      assert_kind_of Arel::Nodes::BindParam, value.right
    end

    def test_rewhere_with_one_overwriting_condition_and_one_unrelated
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone')

      assert_equal 2, relation.where_values.size

      value = relation.where_values.first
      bind  = relation.bind_values.first

      assert_bound_ast value, Post.arel_table['body'], Arel::Nodes::Equality
      assert_equal 'world', bind.last

      value = relation.where_values.second
      bind  = relation.bind_values.second

      assert_bound_ast value, Post.arel_table['title'], Arel::Nodes::Equality
      assert_equal 'alone', bind.last
    end

    def test_rewhere_with_range
      relation = Post.where(comments_count: 1..3).rewhere(comments_count: 3..5)

      assert_equal 1, relation.where_values.size
      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_upper_bound_range
      relation = Post.where(comments_count: 1..Float::INFINITY).rewhere(comments_count: 3..5)

      assert_equal 1, relation.where_values.size
      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_lower_bound_range
      relation = Post.where(comments_count: -Float::INFINITY..1).rewhere(comments_count: 3..5)

      assert_equal 1, relation.where_values.size
      assert_equal Post.where(comments_count: 3..5), relation
    end

    def test_rewhere_with_infinite_range
      relation = Post.where(comments_count: -Float::INFINITY..Float::INFINITY).rewhere(comments_count: 3..5)

      assert_equal 1, relation.where_values.size
      assert_equal Post.where(comments_count: 3..5), relation
    end
  end
end
