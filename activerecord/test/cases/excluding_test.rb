# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class ExcludingTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  setup { @post = posts(:welcome) }

  def test_result_set_does_not_include_single_excluded_record
    assert_not_includes Post.excluding(@post),      @post
    assert_not_includes Post.excluding(@post).to_a, @post

    assert_not_includes Post.without(@post), @post
  end

  def test_result_set_does_not_include_collection_of_excluded_records
    relation = Post.excluding(@post, posts(:thinking))
    assert_not_includes relation, @post
    assert_not_includes relation, posts(:thinking)
  end

  def test_result_set_does_not_include_collection_of_excluded_records_from_a_query
    query = Post.where(id: @post)

    assert_queries_match(/SELECT #{Regexp.escape(quote_table_name("posts.id"))} FROM/) do
      records = Post.excluding(query).to_a

      assert_not_includes records, @post
    end
  end

  def test_result_set_does_not_include_collection_of_excluded_records_from_a_loaded_query
    query = Post.where(id: @post).load

    records = assert_queries_count 1 do
      Post.excluding(query).to_a
    end

    assert_not_includes records, @post
  end

  def test_result_set_does_not_include_collection_of_excluded_records_and_queries
    thinking = posts(:thinking)

    records = assert_queries_count 2 do
      Post.excluding(@post, Post.where(id: thinking)).to_a
    end

    assert_not_includes records, @post
    assert_not_includes records, thinking
  end

  def test_result_set_through_association_does_not_include_single_excluded_record
    comment_greetings, comment_more_greetings = comments(:greetings, :more_greetings)

    relation = @post.comments.excluding(comment_greetings)
    assert_not_includes relation, comment_greetings
    assert_includes     relation, comment_more_greetings
  end

  def test_result_set_through_association_does_not_include_collection_of_excluded_records
    comment_greetings, comment_more_greetings = comments(:greetings, :more_greetings)

    relation = @post.comments.excluding([ comment_greetings, comment_more_greetings ])
    assert_not_includes relation, comment_greetings
    assert_not_includes relation, comment_more_greetings
  end

  def test_result_set_through_association_does_not_include_collection_of_excluded_records_from_a_relation
    relation = @post.comments

    assert_queries_match(/SELECT #{Regexp.escape(quote_table_name("comments.id"))} FROM/) do
      records = Comment.excluding(relation).to_a

      assert_not_empty records
      assert_not_empty @post.comments
      assert_empty records.intersection(@post.comments.to_a)
    end
  end

  def test_result_set_through_association_does_not_include_collection_of_excluded_records_from_a_loaded_relation
    relation = @post.comments.load

    records = assert_queries_count 1 do
      Comment.excluding(relation).to_a
    end

    assert_not_empty records
    assert_not_empty @post.comments
    assert_empty records.intersection(@post.comments.to_a)
  end

  def test_does_not_exclude_records_when_no_arguments
    assert_no_excludes Post.excluding
    assert_no_excludes Post.excluding(nil)
    assert_no_excludes Post.excluding([])
    assert_no_excludes Post.excluding([ nil ])
  end

  def test_raises_on_record_from_different_class
    error = assert_raises(ArgumentError) { Post.excluding(@post, comments(:greetings)) }
    assert_equal "You must only pass a single or collection of Post objects to #excluding.", error.message

    error = assert_raises(ArgumentError) { Post.without(@post, comments(:greetings)) }
    assert_equal "You must only pass a single or collection of Post objects to #without.", error.message
  end

  private
    def assert_no_excludes(relation)
      assert_includes relation, @post
      assert_equal Post.count, relation.count
    end
end
