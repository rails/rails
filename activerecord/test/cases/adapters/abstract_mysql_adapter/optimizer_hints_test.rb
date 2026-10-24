# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/post"

class OptimizerHintsTest < ActiveRecord::AbstractMysqlTestCase
  if supports_optimizer_hints?
    fixtures :posts, :authors

    def setup
      @original_db_warnings_action = :ignore
    end

    def test_optimizer_hints
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain.inspect, "index_posts_on_author_id"
      end
    end

    def test_optimizer_hints_with_count_subquery
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
        posts = posts.select(:id).where(author_id: [0, 1]).limit(5)
        assert_equal 5, posts.count
      end
    end

    def test_optimizer_hints_with_update_all_and_delete_all
      posts = Post.optimizer_hints("NO_INDEX_MERGE(posts)").where(author_id: [0, 1])

      assert_queries_match(%r{\AUPDATE /\*\+ NO_INDEX_MERGE\(posts\) \*/ `posts`}) do
        assert_operator posts.update_all(title: "hinted"), :>, 0
      end

      assert_queries_match(%r{\ADELETE /\*\+ NO_INDEX_MERGE\(posts\) \*/ FROM `posts`}) do
        assert_operator posts.delete_all, :>, 0
      end
    end

    def test_optimizer_hints_with_update_all_and_delete_all_through_subquery
      posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
      posts = posts.joins(:author).where(author_id: [0, 1]).order(:id).limit(1)

      assert_queries_match(%r{\AUPDATE `posts` .* IN \(SELECT `id` FROM \(SELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/ }) do
        assert_equal 1, posts.update_all(title: "hinted")
      end

      assert_queries_match(%r{\ADELETE FROM `posts` .* IN \(SELECT `id` FROM \(SELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/ }) do
        assert_equal 1, posts.delete_all
      end
    end

    def test_optimizer_hints_on_joined_table_with_update_all_and_delete_all_through_subquery
      posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(authors PRIMARY)")
      posts = posts.joins(:author).where(id: 0).order(:id).limit(1)

      with_db_warnings_action(:raise) do
        assert_equal 0, posts.update_all(title: "hinted")
        assert_equal 0, posts.delete_all
      end
    end

    def test_optimizer_hints_is_sanitized
      assert_queries_match(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("/*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain.inspect, "index_posts_on_author_id"
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
