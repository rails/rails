# frozen_string_literal: true

require "cases/helper"
require "models/post"

if supports_use_index_hints?
  class Mysql2UseIndexTest < ActiveRecord::Mysql2TestCase
    fixtures :posts

    def test_use_index
      assert_sql(/\ASELECT COUNT\(count_column\) FROM \(SELECT `posts`\.`id` AS count_column FROM `posts` USE INDEX \(`index_posts_on_type`\) WHERE/) do
        posts = Post.use_index("index_posts_on_type")
        posts = posts.select(:id).where(author_id: [0, 1]).limit(5)
        assert_equal 5, posts.count
      end
    end

    def test_use_index_symbol
      assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX \(`index_posts_on_type`\)/) do
        Post.use_index(:index_posts_on_type).select(:id).load
      end
    end

    def test_use_index_multiple_indexes
      assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX \(`index_posts_on_type`, `index_posts_on_author_id`\)/) do
        Post.use_index("index_posts_on_type", "index_posts_on_author_id").select(:id).load
      end
    end

    def test_use_index_multiple_calls
      assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX \(`index_posts_on_type`\) USE INDEX \(`index_posts_on_author_id`\)/) do
        Post.use_index("index_posts_on_type").use_index("index_posts_on_author_id").select(:id).load
      end
    end

    def test_use_index_multiple_indexes_with_scope
      [[:join, "JOIN"], ["join", "JOIN"], [:order, "ORDER BY"], [:group, "GROUP BY"]].each do |scope, expected_for|
        assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX FOR #{expected_for} \(`index_posts_on_type`, `index_posts_on_author_id`\)/) do
          Post.use_index("index_posts_on_type", "index_posts_on_author_id", scope: scope).select(:id).load
        end
      end
    end

    def test_use_index_multiple_indexes_with_invalid_scope
      assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX \(`index_posts_on_type`, `index_posts_on_author_id`\)/) do
        Post.use_index("index_posts_on_type", "index_posts_on_author_id", scope: :foo).select(:id).load
      end
    end

    def test_use_index_with_blank_values
      assert_sql(/\ASELECT `posts`.`id` FROM `posts`\z/) do
        Post.use_index("").select(:id).load
      end
    end

    def test_use_index_when_merging_two_relations
      assert_sql(/\ASELECT `posts`\.`id` FROM `posts` USE INDEX \(`index_posts_on_type`\) USE INDEX \(`index_posts_on_author_id`\)/) do
        Post.use_index("index_posts_on_type").merge(Post.use_index("index_posts_on_author_id").select(:id)).load
      end
    end
  end
end
