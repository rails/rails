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

  test "parameters are not equal to the hash" do
    @hash = @params.each_pair.to_h
    assert_not_equal @params, @hash
  end

  test "not eql? to equivalent hash" do
    @hash = {}
    @params = ActionController::Parameters.new(@hash)
    assert_not @params.eql?(@hash)
  end

  test "not eql? to equivalent nested hash" do
    @params1 = ActionController::Parameters.new({ foo: {} })
    @params2 = ActionController::Parameters.new({ foo: ActionController::Parameters.new({}) })
    assert_not @params1.eql?(@params2)
  end

  test "not eql? when permitted is different" do
    permitted = @params.permit(:person)
    assert_not @params.eql?(permitted)
  end

  test "eql? when equivalent" do
    permitted = @params.permit(:person)
    assert @params.permit(:person).eql?(permitted)
  end

  test "has_value? converts hashes to parameters" do
    params = ActionController::Parameters.new(foo: { bar: "baz" })
    assert params.has_value?("bar" => "baz")
    params[:foo] # converts value to AC::Params
    assert params.has_value?("bar" => "baz")
  end

  test "has_value? works with parameters" do
    params = ActionController::Parameters.new(foo: { bar: "baz" })
    assert params.has_value?(ActionController::Parameters.new("bar" => "baz"))
  end
end
