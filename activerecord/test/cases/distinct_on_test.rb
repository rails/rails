# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/author"

class DistinctOnTest < ActiveRecord::TestCase
  fixtures :posts, :authors

  def supports_window_functions_for_distinct_on?
    connection = Post.lease_connection
    case connection.adapter_name
    when "Mysql2", "Trilogy"
      connection.database_version >= "8.0"
    else
      true
    end
  end

  def test_on_single_column
    skip "DISTINCT ON requires native support or window functions" unless supports_window_functions_for_distinct_on?
    # Create posts with duplicate author_ids
    author = authors(:david)
    Post.create!(author: author, title: "First", body: "First post")
    Post.create!(author: author, title: "Second", body: "Second post")
    Post.create!(author: author, title: "Third", body: "Third post")

    distinct_posts = Post.where(author: author).distinct_on(:author_id).to_a
    assert_equal 1, distinct_posts.size
    assert_equal author.id, distinct_posts.first.author_id
  end

  def test_on_multiple_columns
    skip "DISTINCT ON requires native support or window functions" unless supports_window_functions_for_distinct_on?
    author1 = authors(:david)
    author2 = authors(:mary)

    # Clean up existing posts for these authors
    Post.where(author: [author1, author2]).delete_all

    # Create posts with different author_id and type combinations
    Post.create!(author: author1, title: "Post 1", body: "Body 1", type: "Post")
    Post.create!(author: author1, title: "Post 2", body: "Body 2", type: "Post")
    Post.create!(author: author1, title: "Special 1", body: "Body 3", type: "SpecialPost")
    Post.create!(author: author2, title: "Post 3", body: "Body 4", type: "Post")

    distinct_posts = Post.where(author: [author1, author2]).distinct_on(:author_id, :type).order(:author_id, :type).to_a
    # Should get: (author1, Post), (author1, SpecialPost), (author2, Post) = 3 records
    assert_equal 3, distinct_posts.size
  end

  def test_with_order_by
    skip "DISTINCT ON requires native support or window functions" unless supports_window_functions_for_distinct_on?
    author = authors(:david)
    Post.where(author: author).delete_all

    post1 = Post.create!(author: author, title: "AAA", body: "Body 1")
    Post.create!(author: author, title: "BBB", body: "Body 2")
    post3 = Post.create!(author: author, title: "ZZZ", body: "Body 3")

    # Get first post by author, ordered by title descending
    result = Post.where(author: author).distinct_on(:author_id).order(:author_id, title: :desc).first
    assert_equal post3.id, result.id
    assert_equal "ZZZ", result.title

    # Get first post by author, ordered by title ascending
    result = Post.where(author: author).distinct_on(:author_id).order(:author_id, :title).first
    assert_equal post1.id, result.id
    assert_equal "AAA", result.title
  end

  def test_with_eager_loading
    skip "DISTINCT ON requires native support or window functions" unless supports_window_functions_for_distinct_on?
    author = authors(:david)
    Post.where(author: author).delete_all

    Post.create!(author: author, title: "Post 1", body: "Body 1")
    Post.create!(author: author, title: "Post 2", body: "Body 2")

    # Test that eager loading works with distinct_on
    results = Post.eager_load(:author).where(author: author).distinct_on(:author_id).to_a
    assert_equal 1, results.size
    assert_equal author.id, results.first.author.id
    # Verify association was eager loaded (won't query DB)
    assert_no_queries { results.first.author.name }
  end

  def test_sql_generation_uses_appropriate_syntax
    skip "DISTINCT ON requires native support or window functions" unless supports_window_functions_for_distinct_on?
    connection = Post.lease_connection
    sql = Post.distinct_on(:author_id).order(:author_id).to_sql

    if connection.adapter_name == "PostgreSQL"
      # PostgreSQL should use native DISTINCT ON syntax
      assert_match(/DISTINCT ON/, sql)
      assert_no_match(/ROW_NUMBER/, sql)
    else
      # Other databases should use window function approach
      assert_match(/ROW_NUMBER\(\) OVER/, sql)
      assert_match(/PARTITION BY/, sql)
      assert_match(/__ar_row_num__/, sql)
      assert_match(/__ar_distinct_on__/, sql)
    end
  end
end
