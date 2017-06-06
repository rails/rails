require "abstract_unit"
require "active_support/core_ext/array/deep_compact"

class DeepCompactTest < ActiveSupport::TestCase
  test "Remove all nil values" do
    original = ["a", "b", nil, [nil, 1] ]
    original.deep_compact!

    assert_equal(["a", "b", [1] ], original)
  end

  test "Remove all nil values without side effect other" do
    original = ["a", "b", nil, [nil, 1] ]
    mapped = original.deep_compact

    assert_equal(["a", "b", nil, [nil, 1] ], original)
    assert_equal(["a", "b", [1] ], mapped)
  end
end
