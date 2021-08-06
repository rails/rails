# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/core_ext/hash/struct"

class HashStructTest < ActiveSupport::TestCase
  test "return values when accessing them" do
    user = { first_name: "Dorian", last_name: "Marié" }.to_struct
    assert_equal "Dorian", user.first_name
    assert_equal "Marié", user.last_name
    assert_raises(NoMethodError) do
      user.birthdate
    end
  end
end
