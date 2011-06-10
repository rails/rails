require 'abstract_unit'

class SafeBufferTest < ActiveSupport::TestCase
  def setup
    @buffer = ActiveSupport::SafeBuffer.new
  end

  test "Should look like a string" do
    assert @buffer.is_a?(String)
    assert_equal "", @buffer
  end

  test "Should escape a raw string which is passed to them" do
    @buffer << "<script>"
    assert_equal "&lt;script&gt;", @buffer
  end

  test "Should NOT escape a safe value passed to it" do
    @buffer << "<script>".html_safe
    assert_equal "<script>", @buffer
  end

  test "Should not mess with an innocuous string" do
    @buffer << "Hello"
    assert_equal "Hello", @buffer
  end

  test "Should not mess with a previously escape test" do
    @buffer << ERB::Util.html_escape("<script>")
    assert_equal "&lt;script&gt;", @buffer
  end

  test "Should be considered safe" do
    assert @buffer.html_safe?
  end

  test "Should return a safe buffer when calling to_s" do
    new_buffer = @buffer.to_s
    assert_equal ActiveSupport::SafeBuffer, new_buffer.class
  end

  test "Should not return safe buffer from gsub" do
    altered_buffer = @buffer.gsub('', 'asdf')
    assert_equal 'asdf', altered_buffer
    assert !altered_buffer.html_safe?
  end

  test "Should not allow gsub! on safe buffers" do
    assert_raise TypeError do
      @buffer.gsub!('', 'asdf')
    end
  end

  test "Should set magic match variables within block passed to gsub" do
    'burn'[/(matches)/]
    @buffer << 'swan'
    @buffer.gsub(/(swan)/) { assert_equal 'swan', $1 }
  end

  test "Should not expect magic match variables after gsub call" do
    'burn'[/(matches)/]
    @buffer << 'vesta'
    @buffer.gsub(/(vesta)/, '')
    assert !$1, %(
      if you can make this test fail it is a _good_ thing: somehow you have
      restored the standard behaviour of SafeBuffer#gsub to make magic matching
      variables available after the call, and you could invert this test
    )
  end

end
