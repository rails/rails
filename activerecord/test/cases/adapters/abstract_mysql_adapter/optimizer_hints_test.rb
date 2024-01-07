# frozen_string_literal: true

require "cases/helper"
require "models/post"

class OptimizerHintsTest < ActiveRecord::AbstractMysqlTestCase
  if supports_optimizer_hints?
    fixtures :posts

    def test_optimizer_hints
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain.inspect, "| index | index_posts_on_author_id | index_posts_on_author_id |"
      end
    end

    def test_optimizer_hints_with_count_subquery
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
        posts = posts.select(:id).where(author_id: [0, 1]).limit(5)
        assert_equal 5, posts.count
      end
    end

    def test_optimizer_hints_is_sanitized
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("/*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain.inspect, "| index | index_posts_on_author_id | index_posts_on_author_id |"
      end

      assert_queries_match(%r{\ASELECT /\*\+ \*\* // `posts`\.\*, // \*\* \*/}) do
        posts = Post.optimizer_hints("**// `posts`.*, //**")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_equal({ "id" => 1 }, posts.first.as_json)
      end
    end

    def test_optimizer_hints_with_unscope
      assert_queries_match(%r{\ASELECT `posts`\.`id`}) do
        posts = Post.optimizer_hints("/*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        posts.unscope(:optimizer_hints).load
      end
    end

    def test_optimizer_hints_with_or
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
          .or(Post.all).load
      end

      queries = capture_sql do
        Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
          .or(Post.optimizer_hints("NO_ICP(posts)")).load
      end
      assert_equal 1, queries.length
      assert_includes queries.first, "NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)"
      assert_not_includes queries.first, "NO_ICP(posts)"

      queries = capture_sql do
        Post.all.or(Post.optimizer_hints("NO_ICP(posts)")).load
      end
      assert_equal 1, queries.length
      assert_not_includes queries.first, "NO_ICP(posts)"
    end
  end
end
