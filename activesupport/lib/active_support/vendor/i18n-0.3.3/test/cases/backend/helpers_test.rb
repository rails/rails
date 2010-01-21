# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nBackendHelpersTest < Test::Unit::TestCase
  def setup
    @backend = I18n::Backend::Simple.new
  end
  
  def test_wind_keys
    hash = { "a" => { "b" => { "c" => "d", "e" => "f" }, "g" => "h" }, "i" => "j"}
    expected = { :"a.b.c" => "d", :"a.b.e" => "f", :"a.g" => "h", :"i" => "j" }
    assert_equal expected, @backend.wind_keys(hash)
  end

  def test_unwind_keys
    hash = { "a.b.c" => "d", :"a.b.e" => "f", :"a.g" => "h", "i" => "j" }
    expected = { "a" => { "b" => { "c" => "d", "e" => "f" }, "g" => "h" }, "i" => "j"}
    assert_equal expected, @backend.unwind_keys(hash)
  end

  def test_deep_symbolize_keys
    result = @backend.deep_symbolize_keys('foo' => { 'bar' => { 'baz' => 'bar' } })
    expected = {:foo => {:bar => {:baz => 'bar'}}}
    assert_equal expected, result
  end
end