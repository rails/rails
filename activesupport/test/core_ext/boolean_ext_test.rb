class BooleanExtAccessTests < Test::Unit::TestCase
  def test_to_param_on_true
    assert_equal true, true.to_param
  end

  def test_to_param_on_false
    assert_equal false, false.to_param
  end
end