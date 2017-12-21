# frozen_string_literal: true

require "cases/helper"
require "models/post"

module ActiveRecord
  class SelectChainTest < ActiveRecord::TestCase
    fixtures :posts

    def test_not_inverts_select_clause
      post = Post.select.not(:title).first
      refute post.has_attribute?(:title)
    end

    def test_not_works_with_multiple_columns
      negated = %i[title body]
      post = Post.select.not(*negated).first

      negated.each do |column|
        refute post.has_attribute?(column)
      end
    end

    def test_not_works_with_arbitrary_columns
      post = Post.select(:id, 'id + 1 AS arbitrary').select.not(:arbitrary).first
      refute post.has_attribute?(:arbitrary)
    end

    def test_plain_selects_all
      post = Post.select.first
      assert Post.column_names.all? { |column| post.has_attribute?(column) }
    end

    def test_chaining_multiple_select_alls
      post = Post.select.select.select.first
      assert Post.column_names.all? { |column| post.has_attribute?(column) }
    end

    def test_chaining_selects_with_select_nots
      post = Post.select.select.not(:title).first
      refute post.has_attribute?(:title)
    end
  end
end
