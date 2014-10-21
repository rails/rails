require 'cases/helper'
require 'models/sti_post'
require 'models/sti_comment'

class StiNameTest < ActiveRecord::TestCase
  fixtures :sti_posts, :sti_comments

  def test_belongs_to
    comment = StiComment.find(100)
    post = comment.item
    assert_equal 1, post.id
  end

  def test_has_many
    post = StiPost.find(1)
    assert_equal 1, post.sti_comments.count
  end

  def test_joins
    post = StiPost.joins(:sti_comments).select('sti_comments.id AS sti_comment_id').first
    assert_equal 100, post[:sti_comment_id]
  end

  def test_replace
    comment = StiComment.find(100)
    post = StiPost.find(2)
    comment.item = post
    assert_equal 'sti_post', comment.item_type
  end

end
