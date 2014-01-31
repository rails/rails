require 'abstract_unit'
require 'active_support/core_ext/object/to_param'
require 'active_support/core_ext/object/to_query'

class ToParamTest < ActiveSupport::TestCase
  def test_object
    foo = Object.new
    def foo.to_s; 'foo' end
    assert_equal 'foo', foo.to_param
  end

  def test_nil
    assert_nil nil.to_param
  end

  def test_boolean
    assert_equal true, true.to_param
    assert_equal false, false.to_param
  end

  def test_nested_empty_hash
    hash1 = {a: 1, b: {c: 3, d: {}}}.to_param
    hash2 = {p: 12, b: {c: 3, e: nil, f: ''}}.to_param
    hash3 = {b: {c: 3, k: {}, f: '' }}.to_param

    assert_equal 'a=1&b[c]=3&b[d]=', CGI::unescape(hash1)
    assert_equal 'b[c]=3&b[e]=&b[f]=&p=12', CGI::unescape(hash2)
    assert_equal 'b[c]=3&b[f]=&b[k]=', CGI::unescape(hash3)
  end
end
