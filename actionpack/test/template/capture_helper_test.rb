require 'abstract_unit'

class CaptureHelperTest < ActionView::TestCase
  def setup
    super
    @_content_for = Hash.new {|h,k| h[k] = "" }
  end

  def test_content_for
    assert ! content_for?(:title)
    content_for :title, 'title'
    assert content_for?(:title)
    assert ! content_for?(:something_else)
  end
end
