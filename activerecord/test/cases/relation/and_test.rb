# frozen_string_literal: true

require "cases/helper"
require "models/author"

module ActiveRecord
  class AndTest < ActiveRecord::TestCase
    fixtures :authors, :author_addresses

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
  end
end
