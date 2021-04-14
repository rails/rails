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

    def test_reselect
      expected = Post.select(:title).to_sql
      assert_equal expected, Post.select(:title, :body).reselect(:title).to_sql
    end

    def test_reselect_with_default_scope_select
      expected = Post.select(:title).to_sql
      actual   = PostWithDefaultSelect.reselect(:title).to_sql

      assert_equal expected, actual
    end

    def test_non_select_columns_wont_be_loaded
      posts = Post.select("UPPER(title) AS title")

      assert_non_select_columns_wont_be_loaded(posts.first)
      assert_non_select_columns_wont_be_loaded(posts.preload(:comments).first)
      assert_non_select_columns_wont_be_loaded(posts.eager_load(:comments).first)
    end

    def assert_non_select_columns_wont_be_loaded(post)
      assert_equal "WELCOME TO THE WEBLOG", post.title
      assert_raise(ActiveModel::MissingAttributeError) do
        post.body
      end
    end
    private :assert_non_select_columns_wont_be_loaded

    def test_merging_select_from_different_model
      posts = Post.select(:id, :title).joins(:comments)
      comments = Comment.where(body: "Thank you for the welcome")

      [
        posts.merge(comments.select(:body)).first,
        posts.merge(comments.select("comments.body")).first,
      ].each do |post|
        assert_equal 1, post.id
        assert_equal "Welcome to the weblog", post.title
        assert_equal "Thank you for the welcome", post.body
      end
    end

    def test_type_casted_extra_select_with_eager_loading
      posts = Post.select("posts.id * 1.1 AS foo").eager_load(:comments)
      assert_equal 1.1, posts.first.foo
    end

    def test_aliased_select_using_as_with_joins_and_includes
      posts = Post.select("posts.id AS field_alias").joins(:comments).includes(:comments)
      assert_equal %w(id field_alias), posts.first.attributes.keys
    end

    def test_aliased_select_not_using_as_with_joins_and_includes
      posts = Post.select("posts.id field_alias").joins(:comments).includes(:comments)
      assert_equal %w(id field_alias), posts.first.attributes.keys
    end

    def test_star_select_with_joins_and_includes
      posts = Post.select("posts.*").joins(:comments).includes(:comments)
      assert_equal %w(
        id author_id title body type legacy_comments_count taggings_with_delete_all_count taggings_with_destroy_count
        tags_count indestructible_tags_count tags_with_destroy_count tags_with_nullify_count
      ), posts.first.attributes.keys
    end
  end
end
