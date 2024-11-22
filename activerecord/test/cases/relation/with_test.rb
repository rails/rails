# frozen_string_literal: true

require "cases/helper"
require "models/comment"
require "models/post"
require "models/company"

module ActiveRecord
  class WithTest < ActiveRecord::TestCase
    fixtures :comments, :posts, :companies

    SPECIAL_POSTS = [2].freeze
    POSTS_WITH_TAGS = [1, 2, 7, 8, 9, 10, 11].freeze
    POSTS_WITH_COMMENTS = [1, 2, 4, 5, 7].freeze
    POSTS_WITH_MULTIPLE_COMMENTS = [1, 4, 5].freeze
    POSTS_WITH_TAGS_AND_COMMENTS = (POSTS_WITH_COMMENTS & POSTS_WITH_TAGS).sort.freeze
    POSTS_WITH_TAGS_AND_MULTIPLE_COMMENTS = (POSTS_WITH_MULTIPLE_COMMENTS & POSTS_WITH_TAGS).sort.freeze

    if ActiveRecord::Base.lease_connection.supports_common_table_expressions?
      def test_with_when_hash_is_passed_as_an_argument
        relation = Post
          .with(posts_with_comments: Post.where("legacy_comments_count > 0"))
          .from("posts_with_comments AS posts")

        assert_equal POSTS_WITH_COMMENTS, relation.order(:id).pluck(:id)
      end

      def test_with_when_hash_with_multiple_elements_of_different_type_is_passed_as_an_argument
        cte_options = {
          posts_with_tags: Post.arel_table.project(Arel.star).where(Post.arel_table[:tags_count].gt(0)),
          posts_with_tags_and_comments: Arel.sql("SELECT * FROM posts_with_tags WHERE legacy_comments_count > 0"),
          "posts_with_tags_and_multiple_comments" => Post.where("legacy_comments_count > 1").from("posts_with_tags_and_comments AS posts")
        }
        relation = Post.with(cte_options).from("posts_with_tags_and_multiple_comments AS posts")

        assert_equal POSTS_WITH_TAGS_AND_MULTIPLE_COMMENTS, relation.order(:id).pluck(:id)
      end

      def test_with_when_invalid_argument_is_passed
        assert_raises ArgumentError, match: /\AUnsupported argument type: #<Post:0x[0-9a-f]+> Post\z/ do
          Post.with(Post.where(type: "Post"))
        end
      end

      def test_multiple_with_calls
        relation = Post
          .with(posts_with_tags: Post.where("tags_count > 0"))
          .from("posts_with_tags_and_comments AS posts")
          .with(posts_with_tags_and_comments: Arel.sql("SELECT * FROM posts_with_tags WHERE legacy_comments_count > 0"))

        assert_equal POSTS_WITH_TAGS_AND_COMMENTS, relation.order(:id).pluck(:id)
      end

      def test_multiple_dupicate_with_calls
        posts_with_tags = Post.where("tags_count > 0")
        relation = Post
          .with(posts_with_tags: posts_with_tags, one_more_posts_with_tags: posts_with_tags)
          .with(posts_with_tags: posts_with_tags)
          .from("posts_with_tags AS posts")

        assert_equal POSTS_WITH_TAGS, relation.order(:id).pluck(:id)
      end

      def test_count_after_with_call
        relation = Post.with(posts_with_comments: Post.where("legacy_comments_count > 0"))

        assert_equal Post.count, relation.count
        assert_equal POSTS_WITH_COMMENTS.size, relation.from("posts_with_comments AS posts").count
        assert_equal POSTS_WITH_COMMENTS.size, relation.joins("JOIN posts_with_comments ON posts_with_comments.id = posts.id").count
      end

      def test_with_when_called_from_active_record_scope
        assert_equal POSTS_WITH_TAGS, Post.with_tags_cte.order(:id).pluck(:id)
      end

      def test_with_when_invalid_params_are_passed
        assert_raise(ArgumentError) { Post.with(posts_with_tags: nil).load }
        assert_raise(ArgumentError) { Post.with(posts_with_tags: [Post.where("tags_count > 0"), 5]).load }
      end

      def test_with_when_passing_arrays
        relation = Post
          .with(posts_with_special_type_or_tags_or_comments: [
            Post.where(type: "SpecialPost"),
            Arel.sql("SELECT * FROM posts WHERE tags_count > 0"), # arel node on purpose
            Post.where("legacy_comments_count > 0")
          ])
          .from("posts_with_special_type_or_tags_or_comments AS posts")

        assert_equal (SPECIAL_POSTS + POSTS_WITH_TAGS + POSTS_WITH_COMMENTS).sort, relation.order(:id).pluck(:id)
      end

      def test_with_when_passing_single_item_array
        relation = Post
          .with(posts_with_special_type_or_tags_or_comments: [Post.where(type: "SpecialPost")])
          .from("posts_with_special_type_or_tags_or_comments AS posts")

        assert_equal SPECIAL_POSTS.sort, relation.order(:id).pluck(:id)
      end

      def test_with_recursive
        top_companies = Company.where(firm_id: nil).to_a
        child_companies = Company.where(firm_id: top_companies).to_a
        top_companies_and_children = (top_companies.map(&:id) + child_companies.map(&:id)).sort

        relation = Company.with_recursive(
          top_companies_and_children: [
            Company.where(firm_id: nil),
            Company.joins("JOIN top_companies_and_children ON companies.firm_id = top_companies_and_children.id"),
          ]
        ).from("top_companies_and_children AS companies")

        assert_equal top_companies_and_children, relation.order(:id).pluck(:id)
        assert_match "WITH RECURSIVE", relation.to_sql
      end

      def test_with_joins
        relation = Post
          .with(commented_posts: Comment.select(:post_id).distinct)
          .joins(:commented_posts)

        assert_equal POSTS_WITH_COMMENTS, relation.order(:id).pluck(:id)
      end

      def test_with_left_joins
        relation = Post
          .with(commented_posts: Comment.select(:post_id).distinct)
          .left_outer_joins(:commented_posts)
          .select("posts.*, commented_posts.post_id as has_comments")

        records = relation.order(:id).to_a

        # Make sure we load all records (thus, left outer join is used)
        assert_equal Post.count, records.size
        assert_equal POSTS_WITH_COMMENTS, records.filter_map { _1.id if _1.has_comments }
      end

      def test_raises_when_using_block
        assert_raises(ArgumentError, match: "does not accept a block") do
          Post.with(attributes_for_inspect: :id) { }
        end
      end

      def test_unscoping
        relation = Post.with(posts_with_comments: Post.where("legacy_comments_count > 0"))

        assert_equal true, relation.values[:with].flat_map(&:keys).include?(:posts_with_comments)
        relation = relation.unscope(:with)
        assert_nil relation.values[:with]
        assert_equal Post.count, relation.count
      end
    else
      def test_common_table_expressions_are_unsupported
        assert_raises ActiveRecord::StatementInvalid do
          Post.with_tags_cte.order(:id).pluck(:id)
        end
      end
    end
  end
end
