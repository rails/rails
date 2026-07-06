# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/author"

module ActiveRecord
  class DistinctElisionTest < ActiveRecord::TestCase
    fixtures :posts, :comments, :authors

    # --- DISTINCT is redundant and dropped: single table, whole-row projection ---

    def test_drops_distinct_for_bare_relation
      assert_no_match(/\bDISTINCT\b/, Post.distinct.to_sql)
    end

    def test_drops_distinct_with_where
      assert_no_match(/\bDISTINCT\b/, Post.where(author_id: 1).distinct.to_sql)
    end

    def test_drops_distinct_for_table_star_select
      assert_no_match(/\bDISTINCT\b/, Post.select("posts.*").distinct.to_sql)
    end

    def test_drops_distinct_for_star_select
      assert_no_match(/\bDISTINCT\b/, Post.select("*").distinct.to_sql)
    end

    def test_drops_distinct_with_limit_and_order
      # ORDER BY on a projected column (whole row) stays valid without DISTINCT.
      assert_no_match(/\bDISTINCT\b/, Post.order(:id).limit(5).distinct.to_sql)
    end

    # --- DISTINCT is kept: it may actually collapse rows ---

    def test_keeps_distinct_with_inner_join
      assert_match(/\bDISTINCT\b/, Post.joins(:comments).distinct.to_sql)
    end

    def test_keeps_distinct_with_left_outer_join
      assert_match(/\bDISTINCT\b/, Post.left_outer_joins(:comments).distinct.to_sql)
    end

    def test_keeps_distinct_with_eager_loading
      assert_match(/\bDISTINCT\b/, Post.eager_load(:comments).distinct.to_sql)
    end

    def test_keeps_distinct_with_group
      assert_match(/\bDISTINCT\b/, Post.group(:author_id).distinct.to_sql)
    end

    def test_keeps_distinct_with_from_subquery
      relation = Post.from("(SELECT * FROM posts) posts").distinct
      assert_match(/\bDISTINCT\b/, relation.to_sql)
    end

    def test_keeps_distinct_for_non_primary_key_projection
      assert_match(/\bDISTINCT\b/, Post.select(:title).distinct.to_sql)
    end

    def test_keeps_distinct_for_explicit_primary_key_projection
      # Tier 1 only elides the whole-row projection; an explicit primary-key
      # select still keeps DISTINCT (a deliberately conservative scope).
      assert_match(/\bDISTINCT\b/, Post.select(:id).distinct.to_sql)
    end

    def test_keeps_distinct_when_model_has_no_primary_key
      no_pk = Class.new(ActiveRecord::Base) do
        self.table_name = "posts"
        self.primary_key = nil
      end
      assert_match(/\bDISTINCT\b/, no_pk.all.distinct.to_sql)
    end

    # --- COUNT(DISTINCT ...) must be unaffected (built via a separate path) ---

    def test_count_distinct_still_uses_count_distinct
      assert_queries_match(/COUNT\(DISTINCT/i, count: 1) do
        Post.distinct.count
      end
    end

    def test_count_distinct_with_join_still_uses_count_distinct
      assert_queries_match(/COUNT\(DISTINCT/i, count: 1) do
        Post.joins(:comments).distinct.count
      end
    end

    # --- Behavioral equivalence: dropping the redundant DISTINCT changes nothing ---

    def test_result_set_is_identical_without_distinct
      assert_equal Post.order(:id).to_a, Post.order(:id).distinct.to_a
    end

    def test_count_is_identical_without_distinct
      assert_equal Post.count, Post.distinct.count
    end
  end
end
