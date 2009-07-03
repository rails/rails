class NilExtAccessTests < Test::Unit::TestCase
  def test_to_param
    assert_nil nil.to_param
  end
end