# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class ExcludingTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_result_set_does_not_include_single_excluded_record
    post = posts(:welcome)

    assert_not_includes Post.excluding(post).to_a, post
  end

  def test_result_set_does_not_include_collection_of_excluded_records
    post_welcome = posts(:welcome)
    post_thinking = posts(:thinking)

    relation = Post.excluding(post_welcome, post_thinking)

    assert_not_includes relation.to_a, post_welcome
    assert_not_includes relation.to_a, post_thinking
  end

  def test_result_set_through_association_does_not_include_single_excluded_record
    post = posts(:welcome)
    comment_greetings = comments(:greetings)
    comment_more_greetings = comments(:more_greetings)

    relation = post.comments.excluding(comment_greetings)

    assert_not_includes relation.to_a, comment_greetings
    assert_includes relation.to_a, comment_more_greetings
  end

  def test_result_set_through_association_does_not_include_collection_of_excluded_records
    post = posts(:welcome)
    comment_greetings = comments(:greetings)
    comment_more_greetings = comments(:more_greetings)

    relation = post.comments.excluding([comment_greetings, comment_more_greetings])

    assert_not_includes relation.to_a, comment_greetings
    assert_not_includes relation.to_a, comment_more_greetings
  end

  def test_does_not_exclude_records_when_no_arguments
    assert_includes Post.excluding(), posts(:welcome)
    assert_equal Post.count, Post.excluding().count
  end

  def test_does_not_exclude_records_with_empty_collection_argument
    assert_includes Post.excluding([]), posts(:welcome)
    assert_equal Post.count, Post.excluding([]).count
  end

  def test_raises_on_record_from_different_class
    post = posts(:welcome)
    comment = comments(:greetings)

    exception = assert_raises ArgumentError do
      Post.excluding(post, comment)
    end
    assert_equal "You must only pass a single or collection of Post objects to #excluding.", exception.message
  end

  def test_result_set_does_not_include_without_record
    post = posts(:welcome)

    assert_not_includes Post.without(post).to_a, post
  end
end
