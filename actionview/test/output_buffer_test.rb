# frozen_string_literal: true

require "abstract_unit"

class TestOutputBuffer < ActiveSupport::TestCase
  setup do
    @buffer = ActionView::OutputBuffer.new
  end

  test "#<< maintains HTML safety" do
    @buffer << "<script>alert('pwned!')</script>"
    assert_predicate @buffer, :html_safe?
    assert_predicate @buffer.to_s, :html_safe?
    assert_equal "&lt;script&gt;alert(&#39;pwned!&#39;)&lt;/script&gt;", @buffer.to_s
  end

  test "#safe_append= bypasses HTML safety" do
    @buffer.safe_append = "<p>This is fine</p>"
    assert_predicate @buffer, :html_safe?
    assert_predicate @buffer.to_s, :html_safe?
    assert_equal "<p>This is fine</p>", @buffer.to_s
  end

  test "can be duped" do
    @buffer << "Hello"
    copy = @buffer.dup
    copy << " World!"
    assert_equal "Hello World!", copy.to_s
    assert_equal "Hello", @buffer.to_s
  end
end
