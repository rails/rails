# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/inclusion"

class ToBoolean < ActiveSupport::TestCase
  def test_object_to_b
    assert true.to_bool
    assert 1.to_bool
    assert "1".to_bool
    assert "t".to_bool
    assert "T".to_bool
    assert "true".to_bool
    assert "TRUE".to_bool
    assert "on".to_bool
    assert "ON".to_bool
    assert " ".to_bool
    assert "\u3000\r\n".to_bool
    assert "\u0000".to_bool
    assert "SOMETHING RANDOM".to_bool

    # explicitly check for false vs nil
    assert_equal false, "".to_bool
    assert_equal false, nil.to_bool
    assert_equal false, false.to_bool
    assert_equal false, 0.to_bool
    assert_equal false, "0".to_bool
    assert_equal false, "f".to_bool
    assert_equal false, "F".to_bool
    assert_equal false, "false".to_bool
    assert_equal false, "FALSE".to_bool
    assert_equal false, "off".to_bool
    assert_equal false, "OFF".to_bool
  end
end
