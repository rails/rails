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

      assert_sql(%r{\ASELECT /\*\+ SeqScan\(posts\) \*/}) do
        posts = Post.optimizer_hints("/*+ SeqScan(posts) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "Seq Scan on posts"
      end
    end
  end
end
