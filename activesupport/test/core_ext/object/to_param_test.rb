# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/to_param"

class ToParamTest < ActiveSupport::TestCase
  class CustomString < String
    def to_param
      "custom-#{ self }"
    end
  end

  def test_object
    foo = Object.new
    def foo.to_s; "foo" end
    assert_equal "foo", foo.to_param
  end

  def test_nil
    assert_nil nil.to_param
  end

  def test_boolean
    assert_equal true, true.to_param
    assert_equal false, false.to_param
  end

  def test_array
    # Empty Array
    assert_equal "", [].to_param

    array = [1, 2, 3, 4]
    assert_equal "1/2/3/4", array.to_param

    # Array of different objects
    array = [1, "3", { a: 1, b: 2 }, nil, true, false, CustomString.new("object")]
    assert_equal "1/3/a=1&b=2//true/false/custom-object", array.to_param
  end
end
