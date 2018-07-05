# frozen_string_literal: true

require "abstract_unit"

class CaptureHelperTest < ActionView::TestCase
  def setup
    super
    @av = ActionView::Base.new
    @view_flow = ActionView::OutputFlow.new
  end

  def test_capture_captures_the_temporary_output_buffer_in_its_block
    assert_nil @av.output_buffer
    string = @av.capture do
      @av.output_buffer << "foo"
      @av.output_buffer << "bar"
    end
    assert_nil @av.output_buffer
    assert_equal "foobar", string
  end

  def test_capture_captures_the_value_returned_by_the_block_if_the_temporary_buffer_is_blank
    string = @av.capture("foo", "bar") do |a, b|
      a + b
    end
    assert_equal "foobar", string
  end

  def test_capture_returns_nil_if_the_returned_value_is_not_a_string
    assert_nil @av.capture { 1 }
  end

  def test_capture_escapes_html
    string = @av.capture { "<em>bar</em>" }
    assert_equal "&lt;em&gt;bar&lt;/em&gt;", string
  end

  def test_capture_doesnt_escape_twice
    string = @av.capture { raw("&lt;em&gt;bar&lt;/em&gt;") }
    assert_equal "&lt;em&gt;bar&lt;/em&gt;", string
  end

  def test_capture_used_for_read
    content_for :foo, "foo"
    assert_equal "foo", content_for(:foo)

    content_for(:bar) { "bar" }
    assert_equal "bar", content_for(:bar)
  end

  def test_content_for_with_multiple_calls
    assert_not content_for?(:title)
    content_for :title, "foo"
    content_for :title, "bar"
    assert_equal "foobar", content_for(:title)
  end

  def test_content_for_with_multiple_calls_and_flush
    assert_not content_for?(:title)
    content_for :title, "foo"
    content_for :title, "bar", flush: true
    assert_equal "bar", content_for(:title)
  end

  def test_content_for_with_block
    assert_not content_for?(:title)
    content_for :title do
      output_buffer << "foo"
      output_buffer << "bar"
      nil
    end
    assert_equal "foobar", content_for(:title)
  end

  def test_content_for_with_block_and_multiple_calls_with_flush
    assert_not content_for?(:title)
    content_for :title do
      "foo"
    end
    content_for :title, flush: true do
      "bar"
    end
    assert_equal "bar", content_for(:title)
  end

  def test_content_for_with_block_and_multiple_calls_with_flush_nil_content
    assert_not content_for?(:title)
    content_for :title do
      "foo"
    end
    content_for :title, nil, flush: true do
      "bar"
    end
    assert_equal "bar", content_for(:title)
  end

  def test_content_for_with_block_and_multiple_calls_without_flush
    assert_not content_for?(:title)
    content_for :title do
      "foo"
    end
    content_for :title, flush: false do
      "bar"
    end
    assert_equal "foobar", content_for(:title)
  end

  def test_content_for_with_whitespace_block
    assert_not content_for?(:title)
    content_for :title, "foo"
    content_for :title do
      output_buffer << "  \n  "
      nil
    end
    content_for :title, "bar"
    assert_equal "foobar", content_for(:title)
  end

  def test_content_for_with_whitespace_block_and_flush
    assert_not content_for?(:title)
    content_for :title, "foo"
    content_for :title, flush: true do
      output_buffer << "  \n  "
      nil
    end
    content_for :title, "bar", flush: true
    assert_equal "bar", content_for(:title)
  end

  def test_content_for_returns_nil_when_writing
    assert_not content_for?(:title)
    assert_nil content_for(:title, "foo")
    assert_nil content_for(:title) { output_buffer << "bar"; nil }
    assert_nil content_for(:title) { output_buffer << "  \n  "; nil }
    assert_equal "foobar", content_for(:title)
    assert_nil content_for(:title, "foo", flush: true)
    assert_nil content_for(:title, flush: true) { output_buffer << "bar"; nil }
    assert_nil content_for(:title, flush: true) { output_buffer << "  \n  "; nil }
    assert_equal "bar", content_for(:title)
  end

  def test_content_for_returns_nil_when_content_missing
    assert_nil content_for(:some_missing_key)
  end

  def test_content_for_question_mark
    assert_not content_for?(:title)
    content_for :title, "title"
    assert content_for?(:title)
    assert_not content_for?(:something_else)
  end

  def test_content_for_should_be_html_safe_after_flush_empty
    assert_not content_for?(:title)
    content_for :title do
      content_tag(:p, "title")
    end
    assert_predicate content_for(:title), :html_safe?
    content_for :title, "", flush: true
    content_for(:title) do
      content_tag(:p, "title")
    end
    assert_predicate content_for(:title), :html_safe?
  end

  def test_provide
    assert_not content_for?(:title)
    provide :title, "hi"
    assert content_for?(:title)
    assert_equal "hi", content_for(:title)
    provide :title, "<p>title</p>"
    assert_equal "hi&lt;p&gt;title&lt;/p&gt;", content_for(:title)

    @view_flow = ActionView::OutputFlow.new
    provide :title, "hi"
    provide :title, raw("<p>title</p>")
    assert_equal "hi<p>title</p>", content_for(:title)
  end

  def test_with_output_buffer_swaps_the_output_buffer_given_no_argument
    assert_nil @av.output_buffer
    buffer = @av.with_output_buffer do
      @av.output_buffer << "."
    end
    assert_equal ".", buffer
    assert_nil @av.output_buffer
  end

  def test_with_output_buffer_swaps_the_output_buffer_with_an_argument
    assert_nil @av.output_buffer
    buffer = ActionView::OutputBuffer.new(".")
    @av.with_output_buffer(buffer) do
      @av.output_buffer << "."
    end
    assert_equal "..", buffer
    assert_nil @av.output_buffer
  end

  def test_with_output_buffer_restores_the_output_buffer
    buffer = ActionView::OutputBuffer.new
    @av.output_buffer = buffer
    @av.with_output_buffer do
      @av.output_buffer << "."
    end
    assert buffer.equal?(@av.output_buffer)
  end

  def test_with_output_buffer_sets_proper_encoding
    @av.output_buffer = ActionView::OutputBuffer.new

    # Ensure we set the output buffer to an encoding different than the default one.
    alt_encoding = alt_encoding(@av.output_buffer)
    @av.output_buffer.force_encoding(alt_encoding)

    @av.with_output_buffer do
      assert_equal alt_encoding, @av.output_buffer.encoding
    end
  end

  def test_with_output_buffer_does_not_assume_there_is_an_output_buffer
    assert_nil @av.output_buffer
    assert_equal "", @av.with_output_buffer {}
  end

  def alt_encoding(output_buffer)
    output_buffer.encoding == Encoding::US_ASCII ? Encoding::UTF_8 : Encoding::US_ASCII
  end
end
