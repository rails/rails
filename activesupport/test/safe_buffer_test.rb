require "abstract_unit"
require "active_support/core_ext/string/inflections"
require "yaml"

class SafeBufferTest < ActiveSupport::TestCase
  def setup
    @buffer = ActiveSupport::SafeBuffer.new
  end

  def test_titleize
    assert_equal "Foo", "foo".html_safe.titleize
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
    str  = "hello!"
    buf  = ActiveSupport::SafeBuffer.new str
    yaml = buf.to_yaml

    assert_match(/^--- #{str}/, yaml)
    assert_equal "hello!", YAML.load(yaml)
  end

  test "Should work in nested to_yaml conversion" do
    str  = "hello!"
    data = { "str" => ActiveSupport::SafeBuffer.new(str) }
    yaml = YAML.dump data
    assert_equal({"str" => str}, YAML.load(yaml))
  end

  test "Should work with primitive-like-strings in to_yaml conversion" do
    assert_equal "true",  YAML.load(ActiveSupport::SafeBuffer.new("true").to_yaml)
    assert_equal "false", YAML.load(ActiveSupport::SafeBuffer.new("false").to_yaml)
    assert_equal "1",     YAML.load(ActiveSupport::SafeBuffer.new("1").to_yaml)
    assert_equal "1.1",   YAML.load(ActiveSupport::SafeBuffer.new("1.1").to_yaml)
  end

  test "Should work with underscore" do
    str = "MyTest".html_safe.underscore
    assert_equal "my_test", str
  end

  test "Should not return safe buffer from gsub" do
    altered_buffer = @buffer.gsub("", "asdf")
    assert_equal "asdf", altered_buffer
    assert !altered_buffer.html_safe?
  end

  test "Should not return safe buffer from gsub!" do
    @buffer.gsub!("", "asdf")
    assert_equal "asdf", @buffer
    assert !@buffer.html_safe?
  end

  test "Should escape dirty buffers on add" do
    clean = "hello".html_safe
    @buffer.gsub!("", "<>")
    assert_equal "hello&lt;&gt;", clean + @buffer
  end

  test "Should concat as a normal string when safe" do
    clean = "hello".html_safe
    @buffer.gsub!("", "<>")
    assert_equal "<>hello", @buffer + clean
  end

  test "Should preserve html_safe? status on copy" do
    @buffer.gsub!("", "<>")
    assert !@buffer.dup.html_safe?
  end

  test "Should return safe buffer when added with another safe buffer" do
    clean = "<script>".html_safe
    result_buffer = @buffer + clean
    assert result_buffer.html_safe?
    assert_equal "<script>", result_buffer
  end

  test "Should raise an error when safe_concat is called on unsafe buffers" do
    @buffer.gsub!("", "<>")
    assert_raise ActiveSupport::SafeBuffer::SafeConcatError do
      @buffer.safe_concat "BUSTED"
    end
  end

  test "Should not fail if the returned object is not a string" do
    assert_kind_of NilClass, @buffer.slice("chipchop")
  end

  test "clone_empty returns an empty buffer" do
    assert_equal "", ActiveSupport::SafeBuffer.new("foo").clone_empty
  end

  test "clone_empty keeps the original dirtyness" do
    assert @buffer.clone_empty.html_safe?
    assert !@buffer.gsub!("", "").clone_empty.html_safe?
  end

  test "Should be safe when sliced if original value was safe" do
    new_buffer = @buffer[0,0]
    assert_not_nil new_buffer
    assert new_buffer.html_safe?, "should be safe"
  end

  test "Should continue unsafe on slice" do
    x = "foo".html_safe.gsub!("f", '<script>alert("lolpwnd");</script>')

    # calling gsub! makes the dirty flag true
    assert !x.html_safe?, "should not be safe"

    # getting a slice of it
    y = x[0..-1]

    # should still be unsafe
    assert !y.html_safe?, "should not be safe"
  end

  test "Should work with interpolation (array argument)" do
    x = "foo %s bar".html_safe % ["qux"]
    assert_equal "foo qux bar", x
  end

  test "Should work with interpolation (hash argument)" do
    x = "foo %{x} bar".html_safe % { x: "qux" }
    assert_equal "foo qux bar", x
  end

  test "Should escape unsafe interpolated args" do
    x = "foo %{x} bar".html_safe % { x: "<br/>" }
    assert_equal "foo &lt;br/&gt; bar", x
  end

  test "Should not escape safe interpolated args" do
    x = "foo %{x} bar".html_safe % { x: "<br/>".html_safe }
    assert_equal "foo <br/> bar", x
  end

  test "Should interpolate to a safe string" do
    x = "foo %{x} bar".html_safe % { x: "qux" }
    assert x.html_safe?, "should be safe"
  end

  test "Should not affect frozen objects when accessing characters" do
    x = "Hello".html_safe
    assert_equal x[/a/, 1], nil
  end
end
