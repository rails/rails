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
      expected = Post.arel_table[@name].not_eq('hello')
      relation = Post.where.not(title: 'hello')
      assert_equal([expected], relation.where_values)
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

      expected = Post.arel_table[@name].eq('hello')
      assert_equal(expected, relation.where_values.first)

      expected = Post.arel_table[@name].not_eq('world')
      assert_equal(expected, relation.where_values.last)
    end

    def test_not_eq_with_succeeding_where
      relation = Post.where.not(title: 'hello').where(title: 'world')

      expected = Post.arel_table[@name].not_eq('hello')
      assert_equal(expected, relation.where_values.first)

      expected = Post.arel_table[@name].eq('world')
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

      expected = Post.arel_table['author_id'].not_in([1, 2])
      assert_equal(expected, relation.where_values[0])

      expected = Post.arel_table[@name].not_eq('ruby on rails')
      assert_equal(expected, relation.where_values[1])
    end
    
    def test_rewhere_with_one_condition
      relation = Post.where(title: 'hello').where(title: 'world').rewhere(title: 'alone')

      expected = Post.arel_table[@name].eq('alone')
      assert_equal 1, relation.where_values.size
      assert_equal expected, relation.where_values.first
    end

    def test_rewhere_with_multiple_overwriting_conditions
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone', body: 'again')

      title_expected = Post.arel_table['title'].eq('alone')
      body_expected  = Post.arel_table['body'].eq('again')

      assert_equal 2, relation.where_values.size
      assert_equal title_expected, relation.where_values.first
      assert_equal body_expected, relation.where_values.second
    end

    def test_rewhere_with_one_overwriting_condition_and_one_unrelated
      relation = Post.where(title: 'hello').where(body: 'world').rewhere(title: 'alone')

      title_expected = Post.arel_table['title'].eq('alone')
      body_expected  = Post.arel_table['body'].eq('world')

      assert_equal 2, relation.where_values.size
      assert_equal body_expected, relation.where_values.first
      assert_equal title_expected, relation.where_values.second
    end
  end
end
