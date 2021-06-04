# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/hash/indifferent_access"

class IndifferentTransformValuesTest < ActiveSupport::TestCase
  test "indifferent access is still indifferent after mapping values" do
    original = { a: "a", b: "b" }.with_indifferent_access
    mapped = original.transform_values { |v| v + "!" }

    assert_equal "a!", mapped[:a]
    assert_equal "a!", mapped["a"]
  end
end
