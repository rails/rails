# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/rating"

module ActiveRecord
  class ReflectionMethodsTest < ActiveRecord::TestCase
    fixtures :posts, :comments, :ratings

    test "Post -> Comment" do
      assert_equal_ids Comment.all.ids, Post.all.comments.ids
    end

    test "Comment -> Post" do
      assert_equal_ids Post.joins(:comments).distinct.pluck(:id),
                       Comment.all.post.ids.uniq
    end

    test "Post -> Comment -> Rating" do
      assert_equal_ids Rating.all.ids, Post.all.comments.ratings.ids
    end

    test "Rating -> Comment -> Post" do
      assert_equal_ids Post.joins(comments: :ratings).distinct.pluck(:id),
                       Rating.all.comment.post.ids.uniq
    end

    private
      def assert_equal_ids(expected, actual)
        assert_equal expected.sort, actual.sort
      end
  end
end
