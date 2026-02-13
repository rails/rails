# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"

class PreloadHasOneLimitTest < ActiveRecord::TestCase
  fixtures :posts, :comments

  def test_preload_has_one_with_limit_returns_correct_record_per_parent
    posts = Post.where(id: [posts(:welcome).id, posts(:thinking).id])
                .order(:id)
                .preload(:limited_last_comment)
                .to_a

    assert_equal comments(:more_greetings), posts[0].limited_last_comment
    assert_equal comments(:does_it_hurt), posts[1].limited_last_comment
  end

  def test_preload_has_one_with_limit_does_not_cause_n_plus_one
    posts = Post.where(id: [posts(:welcome).id, posts(:thinking).id])
                .preload(:limited_last_comment)
                .to_a

    assert_no_queries { posts.each(&:limited_last_comment) }
  end

  def test_preload_has_one_with_limit_alongside_other_associations
    expected_comment_1 = comments(:more_greetings)
    expected_comment_2 = comments(:does_it_hurt)

    posts = Post.where(id: [posts(:welcome).id, posts(:thinking).id])
                .order(:id)
                .preload(:limited_last_comment, :comments)
                .to_a

    assert_no_queries do
      assert_equal expected_comment_1, posts[0].limited_last_comment
      assert_equal 2, posts[0].comments.size
      assert_equal expected_comment_2, posts[1].limited_last_comment
      assert_equal 1, posts[1].comments.size
    end
  end

  def test_preload_has_one_with_limit_with_no_matching_records
    posts = Post.where(id: posts(:authorless).id)
                .preload(:limited_last_comment)
                .to_a

    assert_nil posts.first.limited_last_comment
  end

  def test_includes_has_one_with_limit_returns_correct_record_per_parent
    posts = Post.where(id: [posts(:welcome).id, posts(:thinking).id])
                .order(:id)
                .includes(:limited_last_comment)
                .to_a

    assert_equal comments(:more_greetings), posts[0].limited_last_comment
    assert_equal comments(:does_it_hurt), posts[1].limited_last_comment
  end

  def test_includes_has_one_with_limit_does_not_cause_n_plus_one
    posts = Post.where(id: [posts(:welcome).id, posts(:thinking).id])
                .includes(:limited_last_comment)
                .to_a

    assert_no_queries { posts.each(&:limited_last_comment) }
  end
end
