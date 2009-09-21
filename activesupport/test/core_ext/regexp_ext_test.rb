require 'abstract_unit'
require 'active_support/core_ext/regexp'

class RegexpExtAccessTests < Test::Unit::TestCase
  def test_number_of_captures
    assert_equal 0, //.number_of_captures
    assert_equal 1, /.(.)./.number_of_captures
    assert_equal 2, /.(.).(?:.).(.)/.number_of_captures
    assert_equal 3, /.((.).(?:.).(.))/.number_of_captures
  end

  def test_multiline
    assert_equal true, //m.multiline?
    assert_equal false, //.multiline?
    assert_equal false, /(?m:)/.multiline?
  end

  def test_optionalize
    assert_equal "a?", Regexp.optionalize("a")
    assert_equal "(?:foo)?", Regexp.optionalize("foo")
    assert_equal "", Regexp.optionalize("")
  end

  def test_unoptionalize
    assert_equal "a", Regexp.unoptionalize("a?")
    assert_equal "foo", Regexp.unoptionalize("(?:foo)?")
    assert_equal "", Regexp.unoptionalize("")
  end
end
