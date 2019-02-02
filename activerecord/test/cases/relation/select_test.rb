# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

module ActiveRecord
  class SelectTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    def test_select_with_nil_argument
      expected = Post.select(:title).to_sql
      assert_equal expected, Post.select(nil).select(:title).to_sql
    end

    def test_select_with_joins_populates_attributes_with_aliased_column
      relation = Post.all.select("posts.id as post_id").joins(:comments).includes(:comments)
      assert relation.first.attributes["post_id"].present?
    end
  end
end
