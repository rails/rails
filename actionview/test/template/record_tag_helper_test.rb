require "abstract_unit"

class RecordTagPost
  extend ActiveModel::Naming

  attr_accessor :id, :body

  def initialize
    @id   = 45
    @body = "What a wonderful world!"

    yield self if block_given?
  end
end

class RecordTagHelperTest < ActionView::TestCase

  tests ActionView::Helpers::RecordTagHelper

  def setup
    super
    @post = RecordTagPost.new
  end

  def test_content_tag_for
    assert_raises(NoMethodError) { content_tag_for(:li, @post) }
  end

  def test_div_for
    assert_raises(NoMethodError) { div_for(@post, class: "special") }
  end
end
