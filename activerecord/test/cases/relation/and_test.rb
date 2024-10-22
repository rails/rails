# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"
require "models/categorization"

module ActiveRecord
  class AndTest < ActiveRecord::TestCase
    fixtures :posts, :authors, :author_addresses

    def test_and
      david, mary, bob = authors(:david, :mary, :bob)

      david_and_mary = Author.where(id: [david, mary]).order(:id)
      mary_and_bob   = Author.where(id: [mary, bob]).order(:id)

      assert_equal [mary], david_and_mary.and(mary_and_bob)
    end

    def test_and_with_non_relation_attribute
      hash = { "id" => 123 }
      error = assert_raises(ArgumentError) do
        Author.and(hash)
      end

      assert_equal(
        "You have passed Hash object to #and. Pass an ActiveRecord::Relation object instead.",
        error.message
      )
    end

    def test_and_with_structurally_incompatible_scope
      posts_scope = Author.unscope(:order).limit(10).offset(10).select(:id).order(:id)
      error = assert_raises(ArgumentError) do
        Author.limit(10).select(:id).order(:name).and(posts_scope)
      end

      assert_equal(
        "Relation passed to #and must be structurally compatible. Incompatible values: [:order, :offset]",
        error.message
      )
    end

    def test_and_with_references_inequality
      joined = Post.includes(:author)
      actual = joined.where(authors: { id: 1 })
        .and(Post.where(title: "Welcome to the weblog"))
      expected = Post.where(title: "Welcome to the weblog")
      assert_equal(expected.sort_by(&:id), actual.sort_by(&:id))
    end

    def test_structurally_compatible_values
      assert_nothing_raised do
        Post.includes(:author).includes(:author).and(Post.includes(:author))
        Post.eager_load(:author).eager_load(:author).and(Post.eager_load(:author))
        Post.preload(:author).preload(:author).and(Post.preload(:author))
        Post.group(:author_id).group(:author_id).and(Post.group(:author_id))
        Post.joins(:author).joins(:author).and(Post.joins(:author))
        Post.left_outer_joins(:author).left_outer_joins(:author).and(Post.left_outer_joins(:author))
        Post.from("posts").and(Post.from("posts"))
      end
    end
  end
end
