# frozen_string_literal: true

require "cases/helper"

class PostgreSQLPrefetchedPrimaryKeyTest < ActiveRecord::PostgreSQLTestCase
  class PrefetchedPost < ActiveRecord::Base
    self.table_name = "posts"

    def self.prefetch_primary_key?
      true
    end
  end

  def test_prefetched_pk_uses_sequence_value
    post = PrefetchedPost.create!(title: "T", body: "B")
    assert_not_nil post.id
    assert PrefetchedPost.exists?(post.id)
  end

  def test_prefetched_pk_advances_sequence_per_insert
    post1 = PrefetchedPost.create!(title: "T1", body: "B1")
    post2 = PrefetchedPost.create!(title: "T2", body: "B2")
    assert_equal post1.id + 1, post2.id
  end

  def test_explicit_id_takes_precedence_over_prefetched_id
    post = PrefetchedPost.create!(id: 999_999, title: "Explicit", body: "Body")
    assert_equal 999_999, post.id
    assert PrefetchedPost.exists?(999_999)
  end
end
