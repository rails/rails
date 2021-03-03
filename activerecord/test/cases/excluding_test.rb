# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class ExcludingTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_result_set_does_not_include_single_excluded_record
    assert_not_includes Post.excluding(posts(:welcome)).to_a, posts(:welcome)
  end

  def test_result_set_does_not_include_collection_of_excluded_records
    post_welcome, post_thinking = posts(:welcome, :thinking)

    relation = Post.excluding(post_welcome, post_thinking)
    assert_not_includes relation.to_a, post_welcome
    assert_not_includes relation.to_a, post_thinking
  end

  def test_result_set_through_association_does_not_include_single_excluded_record
    comment_greetings, comment_more_greetings = comments(:greetings, :more_greetings)

    relation = posts(:welcome).comments.excluding(comment_greetings)
    assert_not_includes relation.to_a, comment_greetings
    assert_includes relation.to_a, comment_more_greetings
  end

  def test_result_set_through_association_does_not_include_collection_of_excluded_records
    comment_greetings, comment_more_greetings = comments(:greetings, :more_greetings)

    relation = posts(:welcome).comments.excluding([ comment_greetings, comment_more_greetings ])
    assert_not_includes relation.to_a, comment_greetings
    assert_not_includes relation.to_a, comment_more_greetings
  end

  def test_does_not_exclude_records_when_no_arguments
    assert_no_excludes Post.excluding
    assert_no_excludes Post.excluding(nil)
    assert_no_excludes Post.excluding([])
    assert_no_excludes Post.excluding([ nil ])
  end

  def test_raises_on_record_from_different_class
    error = assert_raises(ArgumentError) { Post.excluding(posts(:welcome), comments(:greetings)) }
    assert_equal "You must only pass a single or collection of Post objects to #excluding.", error.message
  end

  def test_result_set_does_not_include_without_record
    assert_not_includes Post.without(posts(:welcome)).to_a, posts(:welcome)
  end

  private
    def assert_no_excludes(relation)
      assert_includes relation, posts(:welcome)
      assert_equal Post.count, relation.count
    end
end
