require 'abstract_unit'

class CaptureHelperTest < ActionView::TestCase
  def setup
    super
    @av = ActionView::Base.new
    @_content_for = Hash.new {|h,k| h[k] = "" }
  end

  def test_capture_captures_the_temporary_output_buffer_in_its_block
    assert_nil @av.output_buffer
    string = @av.capture do
      @av.output_buffer << 'foo'
      @av.output_buffer << 'bar'
    end
    assert_nil @av.output_buffer
    assert_equal 'foobar', string
    assert_kind_of ActionView::NonConcattingString, string
  end

  def test_capture_captures_the_value_returned_by_the_block_if_the_temporary_buffer_is_blank
    string = @av.capture('foo', 'bar') do |a, b|
      a + b
    end
    assert_equal 'foobar', string
    assert_kind_of ActionView::NonConcattingString, string
  end

  def test_capture_returns_nil_if_the_returned_value_is_not_a_string
    assert_nil @av.capture { 1 }
  end

  def test_capture_escapes_html
    string = @av.capture { '<em>bar</em>' }
    assert_equal '&lt;em&gt;bar&lt;/em&gt;', string
  end

  def test_capture_doesnt_escape_twice
    string = @av.capture { '&lt;em&gt;bar&lt;/em&gt;'.html_safe }
    assert_equal '&lt;em&gt;bar&lt;/em&gt;', string
  end

  def test_content_for
    assert ! content_for?(:title)
    content_for :title, 'title'
    assert content_for?(:title)
    assert ! content_for?(:something_else)
  end

  def test_with_output_buffer_swaps_the_output_buffer_given_no_argument
    assert_nil @av.output_buffer
    buffer = @av.with_output_buffer do
      @av.output_buffer << '.'
    end
    assert_equal '.', buffer
    assert_nil @av.output_buffer
  end

  def test_with_output_buffer_swaps_the_output_buffer_with_an_argument
    assert_nil @av.output_buffer
    buffer = ActionView::OutputBuffer.new('.')
    @av.with_output_buffer(buffer) do
      @av.output_buffer << '.'
    end
    assert_equal '..', buffer
    assert_nil @av.output_buffer
  end

  def test_with_output_buffer_restores_the_output_buffer
    buffer = ActionView::OutputBuffer.new
    @av.output_buffer = buffer
    @av.with_output_buffer do
      @av.output_buffer << '.'
    end
    assert buffer.equal?(@av.output_buffer)
  end

  unless RUBY_VERSION < '1.9'
    def test_with_output_buffer_sets_proper_encoding
      @av.output_buffer = ActionView::OutputBuffer.new

      # Ensure we set the output buffer to an encoding different than the default one.
      alt_encoding = alt_encoding(@av.output_buffer)
      @av.output_buffer.force_encoding(alt_encoding)

      @av.with_output_buffer do
        assert_equal alt_encoding, @av.output_buffer.encoding
      end
    end
  end

  def test_with_output_buffer_does_not_assume_there_is_an_output_buffer
    assert_nil @av.output_buffer
    assert_equal "", @av.with_output_buffer {}
  end

  def test_flush_output_buffer_concats_output_buffer_to_response
    view = view_with_controller
    assert_equal [], view.response.body_parts

    view.output_buffer << 'OMG'
    view.flush_output_buffer
    assert_equal ['OMG'], view.response.body_parts
    assert_equal '', view.output_buffer

    view.output_buffer << 'foobar'
    view.flush_output_buffer
    assert_equal ['OMG', 'foobar'], view.response.body_parts
    assert_equal '', view.output_buffer
  end

  unless RUBY_VERSION < '1.9'
    def test_flush_output_buffer_preserves_the_encoding_of_the_output_buffer
      view = view_with_controller
      alt_encoding = alt_encoding(view.output_buffer)
      view.output_buffer.force_encoding(alt_encoding)
      flush_output_buffer
      assert_equal alt_encoding, view.output_buffer.encoding
    end
  end

  def alt_encoding(output_buffer)
    output_buffer.encoding == Encoding::US_ASCII ? Encoding::UTF_8 : Encoding::US_ASCII
  end

  def view_with_controller
    TestController.new.view_context.tap do |view|
      view.output_buffer = ActionView::OutputBuffer.new
    end
  end
end
