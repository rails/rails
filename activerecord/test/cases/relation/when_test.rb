# frozen_string_literal: true

require "cases/helper"
require "models/car"

module ActiveRecord
  class WhenTest < ActiveRecord::TestCase
    fixtures :cars

    def test_passes_the_value_to_a_proc
      honda = cars(:honda)

      name = "honda"
      expected = Car.where(id: honda)
      actual   = Car.when(name, -> (value) { where(name: value) })

      assert_equal expected.to_a, actual.to_a
    end

    def test_allows_the_value_to_be_directly_used_in_a_hash
      honda = cars(:honda)

      name = "honda"
      expected = Car.where(id: honda)
      actual   = Car.when(name, name: name)

      assert_equal expected.to_a, actual.to_a
    end

    def test_passes_the_relation_through_when_the_value_is_empty_string
      honda = cars(:honda)
      zyke = cars(:zyke)

      name = ""
      expected = Car.where(id: [honda, zyke])
      actual   = Car.when(name, name: name)

      assert_equal expected.to_a, actual.to_a
    end

    def test_passes_the_relation_through_when_the_value_is_nil
      honda = cars(:honda)
      zyke = cars(:zyke)

      name = nil
      expected = Car.where(id: [honda, zyke])
      actual   = Car.when(name, name: name)

      assert_equal expected.to_a, actual.to_a
    end
  end
end
