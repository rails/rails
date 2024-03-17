# frozen_string_literal: true

require "cases/helper"
require "models/post"

class PostgresqlOptimizerHintsTest < ActiveRecord::PostgreSQLTestCase
  if supports_optimizer_hints?
    fixtures :posts

    def setup
      enable_extension!("pg_hint_plan", ActiveRecord::Base.lease_connection)
    end

    def test_optimizer_hints
      assert_queries_match(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("SeqScan(posts)")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "Seq Scan on posts"
      end
    end

    def test_optimizer_hints_with_count_subquery
      assert_queries_match(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("SeqScan(posts)")
        posts = posts.select(:id).where(author_id: [0, 1]).limit(5)
        assert_equal 5, posts.count
      end
    end

    def test_optimizer_hints_is_sanitized
      assert_queries_match(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("/*+ SeqScan(posts) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "Seq Scan on posts"
      end

      assert_queries_match(%r{\ASELECT /\*\+  "posts"\.\*,  \*/}) do
        posts = Post.optimizer_hints("**// \"posts\".*, //**")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_equal({ "id" => 1 }, posts.first.as_json)
      end
    end

    def test_optimizer_hints_with_unscope
      assert_queries_match(%r{\ASELECT "posts"\."id"}) do
        posts = Post.optimizer_hints("/*+ SeqScan(posts) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        posts.unscope(:optimizer_hints).load
      end
    end

    def test_optimizer_hints_with_or
      assert_queries_match(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        Post.optimizer_hints("SeqScan(posts)").or(Post.all).load
      end

      queries = capture_sql do
        Post.optimizer_hints("SeqScan(posts)").or(Post.optimizer_hints("IndexScan(posts)")).load
      end
      assert_equal 1, queries.length
      assert_includes queries.first, "/*+ SeqScan(posts) */"
      assert_not_includes queries.first, "/*+ IndexScan(posts) */"

      queries = capture_sql do
        Post.all.or(Post.optimizer_hints("IndexScan(posts)")).load
      end
      assert_equal 1, queries.length
      assert_not_includes queries.first, "/*+ IndexScan(posts) */"
    end
  end
end
