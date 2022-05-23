# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/object/to_param"

class ToParamTest < ActiveSupport::TestCase
  class CustomString < String
    def to_param
      "custom:#{ self }"
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
    array = [1, "next one", { a: 1, b: 2 }, nil, true, false, CustomString.new("object")]
    assert_equal "1/next one/a=1&b=2//true/false/custom:object", array.to_param
  end

  def test_hash
    assert_equal "", {}.to_param

    hash = { a: 1, b: "next one", c: [3, 2, 1], d: nil, e: true, f: false, g: CustomString.new("object") }
    assert_equal "a=1&b=next one&c[]=3&c[]=2&c[]=1&d=&e=true&f=false&g=custom:object", hash.to_param
  end
end
