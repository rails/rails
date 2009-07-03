class RegexpExtAccessTests < Test::Unit::TestCase
  def test_number_of_captures
    assert_equal 0, //.number_of_captures
    assert_equal 1, /.(.)./.number_of_captures
    assert_equal 2, /.(.).(?:.).(.)/.number_of_captures
    assert_equal 3, /.((.).(?:.).(.))/.number_of_captures
  end

  def test_multiline
    assert   //m.multiline?
    assert ! //.multiline?
    assert ! /(?m:)/.multiline?
  end

  def test_optionalize
    assert "a?", Regexp.optionalize("a")
    assert "(?:foo)?", Regexp.optionalize("foo")
    assert "", Regexp.optionalize("")
  end

  def test_unoptionalize
    assert "a", Regexp.unoptionalize("a?")
    assert "foo", Regexp.unoptionalize("(?:foo)")
    assert "", Regexp.unoptionalize("")
  end
end