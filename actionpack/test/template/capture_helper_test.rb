require 'abstract_unit'

class CaptureHelperTest < ActionView::TestCase
  def setup
    super
    @av = ActionView::Base.new
    @_content_for = Hash.new {|h,k| h[k] = "" }
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
      alt_encoding = @av.output_buffer.encoding == Encoding::US_ASCII ? Encoding::UTF_8 : Encoding::US_ASCII
      @av.output_buffer.force_encoding(alt_encoding)

      @av.with_output_buffer do
        assert alt_encoding, @av.output_buffer.encoding
      end
    end
  end

  def test_with_output_buffer_does_not_assume_there_is_an_output_buffer
    assert_nil @av.output_buffer
    assert_equal "", @av.with_output_buffer {}
  end
end
