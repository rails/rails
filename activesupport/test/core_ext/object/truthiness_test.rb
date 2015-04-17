require 'active_support/core_ext/object'

using Truthiness

class TruthinessTest < ActiveSupport::TestCase
  def test_true_values_are_truthy
    assert 1.truthy?
    assert true.truthy?
    assert 'true'.truthy?
    assert '1'.truthy?
    assert 't'.truthy?
  end

  def test_false_values_are_falsey
    assert 0.falsey?
    assert false.falsey?
    assert 'false'.falsey?
    assert '0'.falsey?
    assert 'f'.falsey?
    assert nil.falsey?
  end
end