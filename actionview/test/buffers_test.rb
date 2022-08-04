# frozen_string_literal: true

require "abstract_unit"

module SharedBufferTests
  def self.included(test_case)
    test_case.test "#<< maintains HTML safety" do
      @buffer << "<script>alert('pwned!')</script>"
      assert_predicate @buffer, :html_safe?
      assert_predicate output, :html_safe?
      assert_equal "&lt;script&gt;alert(&#39;pwned!&#39;)&lt;/script&gt;", output
    end

    test_case.test "#safe_append= bypasses HTML safety" do
      @buffer.safe_append = "<p>This is fine</p>"
      assert_predicate @buffer, :html_safe?
      assert_predicate output, :html_safe?
      assert_equal "<p>This is fine</p>", output
    end

    test_case.test "#raw allow to bypass HTML escaping" do
      raw_buffer = @buffer.raw
      raw_buffer << "<script>alert('pwned!')</script>"
      assert_predicate @buffer, :html_safe?
      assert_predicate output, :html_safe?
      assert_equal "<script>alert('pwned!')</script>", output
    end

    test_case.test "#capture allow to intercept writes" do
      @buffer << "Hello"
      result = @buffer.capture do
        @buffer << "George!"
      end
      assert_equal "George!", result
      assert_predicate result, :html_safe?

      @buffer << " World!"
      assert_equal "Hello World!", output
    end

    test_case.test "#raw respects #capture" do
      @buffer << "Hello"
      raw_buffer = @buffer.raw
      result = @buffer.capture do
        raw_buffer << "George!"
      end
      assert_equal "George!", result
      assert_predicate result, :html_safe?

      @buffer << " World!"
      assert_equal "Hello World!", output
    end
  end
end

class TestOutputBuffer < ActiveSupport::TestCase
  include SharedBufferTests

  setup do
    @buffer = ActionView::OutputBuffer.new
  end

  test "can be duped" do
    @buffer << "Hello"
    copy = @buffer.dup
    copy << " World!"
    assert_equal "Hello World!", copy.to_s
    assert_equal "Hello", output
  end

  private
    def output
      @buffer.to_s
    end
end

class TestStreamingBuffer < ActiveSupport::TestCase
  include SharedBufferTests

  setup do
    @raw_buffer = +""
    @buffer = ActionView::StreamingBuffer.new(@raw_buffer.method(:<<))
  end

  private
    def output
      @raw_buffer.html_safe
    end
end
