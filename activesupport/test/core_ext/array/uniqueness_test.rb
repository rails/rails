require "abstract_unit"
require "active_support/core_ext/array/uniqueness"

class UniquenessTest < ActiveSupport::TestCase
  def test_uniq?
    assert_equal [1, 2, 3, "a", 4].uniq?, true
    assert_equal [1, 2, 3, "a", 4, "a"].uniq?, false
    assert_equal [].uniq?, true
  end
end
