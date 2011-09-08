require 'abstract_unit'
begin
  require 'psych'
rescue LoadError
end

require 'active_support/core_ext/string/inflections'
require 'yaml'

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

  test "Should be converted to_yaml" do
    str  = 'hello!'
    buf  = ActiveSupport::SafeBuffer.new str
    yaml = buf.to_yaml

    assert_match(/^--- #{str}/, yaml)
    assert_equal 'hello!', YAML.load(yaml)
  end

  test "Should work in nested to_yaml conversion" do
    str  = 'hello!'
    data = { 'str' => ActiveSupport::SafeBuffer.new(str) }
    yaml = YAML.dump data
    assert_equal({'str' => str}, YAML.load(yaml))
  end

  test "Should work with underscore" do
    str = "MyTest".html_safe.underscore
    assert_equal "my_test", str
  end

  test "Should not return safe buffer from capitalize" do
    altered_buffer = "asdf".html_safe.capitalize
    assert_equal 'Asdf', altered_buffer
    assert !altered_buffer.html_safe?
  end

  test "Should not return safe buffer from gsub!" do
    string = "asdf"
    string.capitalize!
    assert_equal 'Asdf', string
    assert !string.html_safe?
  end

  test "Should escape dirty buffers on add" do
    clean = "hello".html_safe
    assert_equal "hello&lt;&gt;", clean + '<>'
  end

  test "Should concat as a normal string when dirty" do
    clean = "hello".html_safe
    assert_equal "<>hello", '<>' + clean
  end

  test "Should preserve dirty? status on copy" do
    dirty = "<>"
    assert !dirty.dup.html_safe?
  end

  test "Should raise an error when safe_concat is called on dirty buffers" do
    @buffer.capitalize!
    assert_raise ActiveSupport::SafeBuffer::SafeConcatError do
      @buffer.safe_concat "BUSTED"
    end
  end

  test "should not fail if the returned object is not a string" do
    assert_kind_of NilClass, @buffer.slice("chipchop")
  end

  test "Should initialize @dirty to false for new instance when sliced" do
    dirty = @buffer[0,0].send(:dirty?)
    assert_not_nil dirty
    assert !dirty
  end

  ["gsub", "sub"].each do |unavailable_method|
    test "should raise on #{unavailable_method}" do
      assert_raise NoMethodError, "#{unavailable_method} cannot be used with a safe string. You should use object.to_str.#{unavailable_method}" do
        @buffer.send(unavailable_method, '', '<>')
      end
    end

    test "should raise on #{unavailable_method}!" do
      assert_raise NoMethodError, "#{unavailable_method}! cannot be used with a safe string. You should use object.to_str.#{unavailable_method}!" do
        @buffer.send("#{unavailable_method}!", '', '<>')
      end
    end
  end
end
