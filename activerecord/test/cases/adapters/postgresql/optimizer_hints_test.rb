# frozen_string_literal: true

require "cases/helper"
require "models/post"

if supports_optimizer_hints?
  class PostgresqlOptimzerHintsTest < ActiveRecord::PostgreSQLTestCase
    fixtures :posts

    def setup
      enable_extension!("pg_hint_plan", ActiveRecord::Base.connection)
    end

    def test_optimizer_hints
      assert_sql(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("SeqScan(posts)")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "Seq Scan on posts"
      end
    end

    def test_optimizer_hints_with_count_subquery
      assert_sql(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("SeqScan(posts)")
        posts = posts.select(:id).where(author_id: [0, 1]).limit(5)
        assert_equal 5, posts.count
      end
    end

    def test_optimizer_hints_is_sanitized
      assert_sql(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("/*+ SeqScan(posts) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "Seq Scan on posts"
      end

      assert_sql(%r{\ASELECT /\*\+  "posts"\.\*,  \*/}) do
        posts = Post.optimizer_hints("**// \"posts\".*, //**")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_equal({ "id" => 1 }, posts.first.as_json)
      end
    end

    def test_optimizer_hints_with_unscope
      assert_sql(%r{\ASELECT "posts"\."id"}) do
        posts = Post.optimizer_hints("/*+ SeqScan(posts) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        posts.unscope(:optimizer_hints).load
      end
    end
  end
end
