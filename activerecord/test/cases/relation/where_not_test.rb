# frozen_string_literal: true

require "cases/helper"
require "models/cake_designer"
require "models/drink_designer"
require "models/chef"
require "models/post"

module ActiveRecord
  class WhereNotTest < ActiveRecord::TestCase
    def test_where_not_with_polymorphic_association
      chef1 = Chef.create!
      chef2 = Chef.create!
      chef3 = Chef.create!

      cake_designer1 = CakeDesigner.create!(chef: chef1)
      cake_designer2 = CakeDesigner.create!(chef: chef2)
      drink_designer3 = DrinkDesigner.create!(chef: chef3)

      chefs = Chef.where.not(employable: cake_designer1)

      assert_not_includes chefs, chef1
      assert_includes chefs, chef2
      assert_includes chefs, chef3
    end

    def test_where_not_with_multiple_condition
      post1 = Post.create(title: "t1", body: "b1")
      post2 = Post.create(title: "t2", body: "b2")

      scope = Post.where.not(title: "t1", body: "b1")
      assert_not_includes scope, post1
      assert_includes scope, post2

      scope = Post.where.not(title: "t1", body: "b2")
      assert_includes scope, post1
      assert_includes scope, post2
    end

    def test_where_not_with_multiple_condition_eq_inverted_where_clause
      relation = Post.where.not(author_id: [1, 2], title: "ruby on rails")
      expected_where_clause =
        Post.where(author_id: [1, 2], title: "ruby on rails").where_clause.invert
      assert_equal expected_where_clause, relation.where_clause
    end

    def test_where_not_with_multiple_condition_not_eq_few_where_not_with_single_condition
      relation1 = Post.where.not(author_id: [1, 2], title: "ruby on rails")
      relation2 = Post.where.not(author_id: [1, 2]).where.not(title: "ruby on rails")
      assert_not_equal relation1.where_clause, relation2.where_clause
    end
  end
end
