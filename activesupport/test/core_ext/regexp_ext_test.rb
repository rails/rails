require 'abstract_unit'
require 'active_support/core_ext/regexp'

class RegexpExtAccessTests < ActiveSupport::TestCase
  def test_multiline
    assert_equal true, //m.multiline?
    assert_equal false, //.multiline?
    assert_equal false, /(?m:)/.multiline?
  end

  # Based on https://github.com/ruby/ruby/blob/trunk/test/ruby/test_regexp.rb.
  def test_match_p
    /back(...)/ =~ 'backref'
    # must match here, but not in a separate method, e.g., assert_send,
    # to check if $~ is affected or not.
    assert_equal false, //.match?(nil)
    assert_equal true, //.match?("")
    assert_equal true, /.../.match?(:abc)
    assert_raise(TypeError) { /.../.match?(Object.new) }
    assert_equal true, /b/.match?('abc')
    assert_equal true, /b/.match?('abc', 1)
    assert_equal true, /../.match?('abc', 1)
    assert_equal true, /../.match?('abc', -2)
    assert_equal false, /../.match?("abc", -4)
    assert_equal false, /../.match?("abc", 4)
    assert_equal true, /\z/.match?("")
    assert_equal true, /\z/.match?("abc")
    assert_equal true, /R.../.match?("Ruby")
    assert_equal false, /R.../.match?("Ruby", 1)
    assert_equal false, /P.../.match?("Ruby")
    assert_equal 'backref', $&
    assert_equal 'ref', $1
  end
end
