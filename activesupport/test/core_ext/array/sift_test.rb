# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/array"

class SiftTest < ActiveSupport::TestCase
  def test_sift
    array = [1, "one"]

    assert_equal 1, array.sift(1)
    assert_equal "one", array.sift("one")
    assert_nil array.sift("not_exist")
    assert_nil array.sift(nil)
  end

  def test_sift_with_boolean
    assert_equal true, [true].sift(true)
    assert_equal false, [false].sift(false)
    assert_nil [true].sift(false)
    assert_nil [false].sift(true)
  end

  def test_sift_with_hash
    hash = { key: "value" }
    array = [hash]

    assert_equal hash, array.sift(hash)
    assert_nil array.sift(:key)
  end

  def test_sift_with_array
    array = [[], ["one"], ["one", "two"]]

    assert_equal ["one"], array.sift(["one"])
    assert_equal [], array.sift([])
    assert_nil array.sift("one")
    assert_nil array.sift(["two"])
  end
end
