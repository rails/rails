# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class ParametersAccessorsTest < ActiveSupport::TestCase
  setup do
    ActionController::Parameters.permit_all_parameters = false

    @params = ActionController::Parameters.new(
      person: {
        age: "32",
        name: {
          first: "David",
          last: "Heinemeier Hansson"
        },
        addresses: [{ city: "Chicago", state: "Illinois" }]
      }
    )
  end

  test "deprecated comparison works" do
    assert_kind_of Enumerator, @params.each_pair
    assert_deprecated do
      assert_equal @params, @params.each_pair.to_h
    end
  end

  test "deprecated comparison disabled" do
    without_deprecated_params_hash_equality do
      assert_kind_of Enumerator, @params.each_pair
      assert_not_deprecated do
        assert_not_equal @params, @params.each_pair.to_h
      end
    end
  end

  test "has_value? converts hashes to parameters" do
    assert_not_deprecated do
      params = ActionController::Parameters.new(foo: { bar: "baz" })
      assert params.has_value?("bar" => "baz")
      params[:foo] # converts value to AC::Params
      assert params.has_value?("bar" => "baz")
    end
  end

  test "has_value? works with parameters" do
    without_deprecated_params_hash_equality do
      params = ActionController::Parameters.new(foo: { bar: "baz" })
      assert params.has_value?(ActionController::Parameters.new("bar" => "baz"))
    end
  end

  private
    def without_deprecated_params_hash_equality
      ActionController::Parameters.allow_deprecated_parameters_hash_equality = false
      yield
    ensure
      ActionController::Parameters.allow_deprecated_parameters_hash_equality = true
    end
end
