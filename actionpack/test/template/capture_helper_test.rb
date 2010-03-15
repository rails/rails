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

  def test_with_output_buffer_does_not_assume_there_is_an_output_buffer
    av = ActionView::Base.new
    assert_nil av.output_buffer
    assert_equal "", av.with_output_buffer {}
  end
end
