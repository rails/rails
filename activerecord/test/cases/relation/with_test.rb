# frozen_string_literal: true

require "cases/helper"
require "models/comment"
require "models/post"

module ActiveRecord
  class WithTest < ActiveRecord::TestCase
    fixtures :comments
    fixtures :posts

    def test_with_when_name_and_expression_is_passed_as_argument
      posts_with_comments = Post.where("legacy_comments_count > 0")
      actual = Post.with(:posts_with_comments, posts_with_comments).from("posts_with_comments AS posts")
      assert_equal posts_with_comments.to_a, actual
    end

    def test_with_when_hash_is_passed_as_an_argument
      posts_with_comments = Post.where("legacy_comments_count > 0")
      actual = Post.with(posts_with_comments: posts_with_comments).from("posts_with_comments AS posts")
      assert_equal posts_with_comments.to_a, actual
    end

    def test_with_when_arel_node_as_is_passed_as_an_argument
      posts_with_comments = Post.where("legacy_comments_count > 0")
      posts_table = Arel::Table.new(:posts)
      cte_table = Arel::Table.new(:posts_with_comments)
      cte_select = posts_table.project(Arel.star).where(posts_table[:legacy_comments_count].gt(0))
      as = Arel::Nodes::As.new(cte_table, cte_select)
      actual = Post.with(as).from("posts_with_comments AS posts")
      assert_equal posts_with_comments.to_a, actual
    end

    def test_with_when_arel_table_alias_is_passed_as_an_argument
      posts_with_comments = Post.where("legacy_comments_count > 0")
      expression = Post.arel_table.project(Arel.star).where(Post.arel_table[:legacy_comments_count].gt(0))
      table_alias = Arel::Nodes::TableAlias.new(expression, :posts_with_comments)
      actual = Post.with(table_alias).from("posts_with_comments AS posts")
      assert_equal posts_with_comments.to_a, actual
    end

    def test_with_when_array_of_arel_node_as_and_table_alias_is_passed_as_an_argument
      posts_with_tags_and_comments = Post.where("legacy_comments_count > 0").where("tags_count > 0")

      posts_table = Arel::Table.new(:posts)
      posts_with_comments_table = Arel::Table.new(:posts_with_comments)
      posts_with_comments_expression = posts_table.project(Arel.star).where(posts_table[:legacy_comments_count].gt(0))
      as = Arel::Nodes::As.new(posts_with_comments_table, posts_with_comments_expression)
      posts_with_tags_and_comments_expression = posts_with_comments_table.project(Arel.star).where(posts_with_comments_table[:tags_count].gt(0))
      table_alias = Arel::Nodes::TableAlias.new(posts_with_tags_and_comments_expression, :posts_with_tags_and_comments)

      actual = Post.with([as, table_alias]).from("posts_with_tags_and_comments AS posts")
      assert_equal posts_with_tags_and_comments.to_a, actual
    end

    def test_with_when_hash_with_multiple_elements_of_different_type_is_passed_as_an_argument
      posts_with_tags_and_multiple_comments = Post.where("tags_count > 0").where("legacy_comments_count > 1")
      posts_arel_table = Arel::Table.new(:posts)
      cte_options = {
        posts_with_tags: posts_arel_table.project(Arel.star).where(posts_arel_table[:tags_count].gt(0)),
        posts_with_tags_and_comments: "SELECT * FROM posts_with_tags WHERE legacy_comments_count > 0",
        "posts_with_tags_and_multiple_comments" => Post.where("legacy_comments_count > 1").from("posts_with_tags_and_comments AS posts")
      }
      actual = Post.with(cte_options).from("posts_with_tags_and_multiple_comments AS posts")
      assert_equal posts_with_tags_and_multiple_comments.to_a, actual
    end

    def test_with_recursive_when_union_is_composed_from_ar_relations
      comment = Comment.last
      first_reply = Comment.create!(body: "First reply", parent: comment, post: comment.post)
      sub_reply = Comment.create!(body: "Reply to first reply", parent: first_reply, post: comment.post)
      second_reply = Comment.create!(body: "Second reply", parent: comment, post: comment.post)

      non_recursive_relation = Comment.select(:id, :parent_id, 0).where(parent: comment)
      recursive_relation = Comment.select(:id, :parent_id, "replies.depth + 1").joins("JOIN replies ON comments.parent_id = replies.id")
      replies = Comment
        .with_recursive("replies(id, parent_id, depth)", non_recursive_relation, recursive_relation)
        .from("replies")
        .order(:id)

      assert_match(/UNION ALL SELECT/, replies.to_sql)
      assert_equal [[first_reply.id, 0], [sub_reply.id, 1], [second_reply.id, 0]], replies.pluck(:id, :depth)
    end

    def test_with_recursive_using_union_instead_of_union_all
      non_recursive_relation = Comment.select(:id, :parent_id, "0").where(parent: Comment.last)
      recursive_relation = Comment.select(:id, :parent_id, "replies.depth + 1").joins("JOIN replies ON comments.parent_id = replies.id")
      replies = Comment
        .with_recursive("replies(id, parent_id, depth)", non_recursive_relation, recursive_relation, union_all: false)
        .from("replies")
        .order(:id)

      assert_match(/UNION SELECT/, replies.to_sql)
    end

    def test_with_recursive_when_union_is_passed_as_string
      comment = Comment.last
      first_reply = Comment.create!(body: "First reply", parent: comment, post: comment.post)
      sub_reply = Comment.create!(body: "Reply to first reply", parent: first_reply, post: comment.post)
      second_reply = Comment.create!(body: "Second reply", parent: comment, post: comment.post)

      union = %{
        SELECT comments.id, comments.parent_id FROM comments WHERE comments.id = #{comment.id}
        UNION
        SELECT comments.id, comments.parent_id FROM comments INNER JOIN thread ON comments.parent_id = thread.id
      }
      thread = Comment.with_recursive(thread: union).from("thread AS comments").order(:id)

      assert_equal [comment.id, first_reply.id, sub_reply.id, second_reply.id], thread.pluck(:id)
    end

    def test_with_recursive_when_union_is_passed_as_arel_node
      comment = Comment.last
      first_reply = Comment.create!(body: "First reply", parent: comment, post: comment.post)
      sub_reply = Comment.create!(body: "Reply to first reply", parent: first_reply, post: comment.post)
      second_reply = Comment.create!(body: "Second reply", parent: comment, post: comment.post)

      non_recursive_relation = Comment.select(:id, :parent_id, "0").where(parent: comment)
      recursive_relation = Comment.select(:id, :parent_id, "replies.depth + 1").joins("JOIN replies ON comments.parent_id = replies.id")
      union = non_recursive_relation.arel.union("all", recursive_relation.arel)
      replies = Comment
        .with_recursive("replies(id, parent_id, depth)" => union)
        .from("replies AS comments")
        .order(:id)
      assert_equal [[first_reply.id, 0], [sub_reply.id, 1], [second_reply.id, 0]], replies.pluck(:id, :depth)
    end

    def test_multiple_with_calls
      posts_with_tags_and_comments = Post.where("tags_count > 0").where("legacy_comments_count > 0")
      actual = Post
        .with(:posts_with_tags, Post.where("tags_count > 0"))
        .from("posts_with_tags_and_comments AS posts")
        .with(posts_with_tags_and_comments: "SELECT * FROM posts_with_tags WHERE legacy_comments_count > 0")
      assert_equal posts_with_tags_and_comments.to_a, actual
    end

    def test_multiple_with_and_with_recursive_calls
      top_comment = Comment.last
      first_reply = Comment.create!(body: "First reply", parent: top_comment, post: top_comment.post)
      sub_reply = Comment.create!(body: "Reply to first reply", parent: first_reply, post: top_comment.post)
      second_reply = Comment.create!(body: "Second reply", parent: top_comment, post: top_comment.post)

      non_recursive_relation = Comment.select(:id, :parent_id, 0).joins("JOIN top_comment ON top_comment.id = comments.parent_id")
      recursive_relation = Comment.select(:id, :parent_id, "replies.depth + 1").joins("JOIN replies ON comments.parent_id = replies.id")
      replies = Comment
        .with(:top_comment, Comment.where(id: top_comment.id).select(:id))
        .with_recursive("replies(id, parent_id, depth)", non_recursive_relation, recursive_relation)
        .from("replies")
        .order(:id)

      assert_equal [[first_reply.id, 0], [sub_reply.id, 1], [second_reply.id, 0]], replies.pluck(:id, :depth)
    end

    def test_count_after_with_call
      posts_count = Post.all.count
      posts_with_legacy_comments_count = Post.where("legacy_comments_count > 0").count
      assert posts_count > posts_with_legacy_comments_count

      with_relation = Post.with(posts_with_comments: Post.where("legacy_comments_count > 0"))
      assert_equal posts_count, with_relation.count
      assert_equal posts_with_legacy_comments_count, with_relation.from("posts_with_comments AS posts").count
      assert_equal posts_with_legacy_comments_count, with_relation.joins("JOIN posts_with_comments ON posts_with_comments.id = posts.id").count
    end

    def test_with_when_called_from_active_record_scope
      posts_with_tags = Post.where("tags_count > 0")
      assert_equal posts_with_tags.to_a, Post.with_tags_cte
    end

    def test_with_when_invalid_params_are_passed
      assert_raise(ArgumentError) { Post.with }
      assert_raise(ArgumentError) { Post.with([{ posts_with_tags: Post.where("tags_count > 0") }]).load }
    end

    def test_with_when_invalid_hash_values_are_passed
      assert_raise(ArgumentError) { Post.with(posts_with_tags: nil).load }
      assert_raise(ArgumentError) { Post.with(posts_with_tags: [Post.where("tags_count > 0")]).load }
    end
  end
end
