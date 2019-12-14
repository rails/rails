# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

if ActiveRecord::Base.connection.supports_common_table_expressions?
  class WithTest < ActiveRecord::TestCase
    fixtures :posts, :comments

    def test_with
      result = Comment.with(my_posts: Post.where(author_id: 1)).joins("JOIN my_posts ON my_posts.id = comments.post_id")
      assert_match(/^WITH/, result.to_sql)
      assert_equal 10, result.count
    end

    def test_multiple_with
      result = Comment.with(my_posts: Post.where(author_id: 1), their_posts: Post.where(author_id: 2)).load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/my_posts/, sql)
      assert_match(/their_posts/, sql)
    end

    def test_multiple_with_calls
      result = Comment.with(my_posts: Post.where(author_id: 1)).with(their_posts: Post.where(author_id: 2)).load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/my_posts/, sql)
      assert_match(/their_posts/, sql)
    end

    def test_with_with_arel
      arel_table = Arel::Table.new("posts")
      arel_manager = arel_table.project(arel_table[:author_id])
      result = Comment.with(arel_posts: arel_manager).load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/arel_posts/, sql)
    end

    def test_with_with_string
      result = Comment.with(Arel.sql("sql_posts AS (SELECT * FROM posts where author_id = 1)")).load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/sql_posts/, sql)
    end

    def test_with_with_hash_string
      result = Comment.with(sql_posts: Arel.sql("SELECT * FROM posts where author_id = 1")).load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/sql_posts/, sql)
    end

    def test_merge_with
      result = Comment.all.merge(Post.with(my_posts: Post.where(author_id: 7))).joins("JOIN my_posts ON my_posts.id = comments.post_id").load
      sql = result.to_sql

      assert_match(/^WITH/, sql)
      assert_match(/my_posts/, sql)
    end
  end
end
