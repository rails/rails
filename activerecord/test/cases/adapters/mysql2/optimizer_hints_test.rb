# frozen_string_literal: true

require "cases/helper"
require "models/post"

if supports_optimizer_hints?
  class Mysql2OptimzerHintsTest < ActiveRecord::Mysql2TestCase
    fixtures :posts

    def test_optimizer_hints
      assert_sql(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id)")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "| index | index_posts_on_author_id | index_posts_on_author_id |"
      end

      assert_sql(%r{\ASELECT /\*\+ NO_RANGE_OPTIMIZATION\(posts index_posts_on_author_id\) \*/}) do
        posts = Post.optimizer_hints("/*+ NO_RANGE_OPTIMIZATION(posts index_posts_on_author_id) */")
        posts = posts.select(:id).where(author_id: [0, 1])
        assert_includes posts.explain, "| index | index_posts_on_author_id | index_posts_on_author_id |"
      end
    end
  end
end
