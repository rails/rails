# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"
require "active_support/core_ext/hash/transform_values"

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

  test "[] retains permitted status" do
    @params.permit!
    assert_predicate @params[:person], :permitted?
    assert_predicate @params[:person][:name], :permitted?
  end

  test "[] retains unpermitted status" do
    assert_not_predicate @params[:person], :permitted?
    assert_not_predicate @params[:person][:name], :permitted?
  end

  test "as_json returns the JSON representation of the parameters hash" do
    assert_not @params.as_json.key? "parameters"
    assert_not @params.as_json.key? "permitted"
    assert @params.as_json.key? "person"
  end

  test "to_s returns the string representation of the parameters hash" do
    assert_equal '{"person"=>{"age"=>"32", "name"=>{"first"=>"David", "last"=>"Heinemeier Hansson"}, ' \
      '"addresses"=>[{"city"=>"Chicago", "state"=>"Illinois"}]}}', @params.to_s
  end

  test "each carries permitted status" do
    @params.permit!
    @params.each { |key, value| assert(value.permitted?) if key == "person" }
  end

  test "each carries unpermitted status" do
    @params.each { |key, value| assert_not(value.permitted?) if key == "person" }
  end

  test "each returns key,value array for block with arity 1" do
    @params.each do |arg|
      assert_kind_of Array, arg
      assert_equal "person", arg[0]
      assert_kind_of ActionController::Parameters, arg[1]
    end
  end

  test "each_pair carries permitted status" do
    @params.permit!
    @params.each_pair { |key, value| assert(value.permitted?) if key == "person" }
  end

  test "each_pair carries unpermitted status" do
    @params.each_pair { |key, value| assert_not(value.permitted?) if key == "person" }
  end

  test "each_pair returns key,value array for block with arity 1" do
    @params.each_pair do |arg|
      assert_kind_of Array, arg
      assert_equal "person", arg[0]
      assert_kind_of ActionController::Parameters, arg[1]
    end
  end

  test "empty? returns true when params contains no key/value pairs" do
    params = ActionController::Parameters.new
    assert_predicate params, :empty?
  end

  test "empty? returns false when any params are present" do
    assert_not_predicate @params, :empty?
  end

  test "except retains permitted status" do
    @params.permit!
    assert_predicate @params.except(:person), :permitted?
    assert_predicate @params[:person].except(:name), :permitted?
  end

  test "except retains unpermitted status" do
    assert_not_predicate @params.except(:person), :permitted?
    assert_not_predicate @params[:person].except(:name), :permitted?
  end

  test "fetch retains permitted status" do
    @params.permit!
    assert_predicate @params.fetch(:person), :permitted?
    assert_predicate @params[:person].fetch(:name), :permitted?
  end

  test "fetch retains unpermitted status" do
    assert_not_predicate @params.fetch(:person), :permitted?
    assert_not_predicate @params[:person].fetch(:name), :permitted?
  end

  test "has_key? returns true if the given key is present in the params" do
    assert @params.has_key?(:person)
  end

  test "has_key? returns false if the given key is not present in the params" do
    assert_not @params.has_key?(:address)
  end

  test "has_value? returns true if the given value is present in the params" do
    params = ActionController::Parameters.new(city: "Chicago", state: "Illinois")
    assert params.has_value?("Chicago")
  end

  test "has_value? returns false if the given value is not present in the params" do
    params = ActionController::Parameters.new(city: "Chicago", state: "Illinois")
    assert_not params.has_value?("New York")
  end

  test "include? returns true if the given key is present in the params" do
    assert @params.include?(:person)
  end

  test "include? returns false if the given key is not present in the params" do
    assert_not @params.include?(:address)
  end

  test "key? returns true if the given key is present in the params" do
    assert @params.key?(:person)
  end

  test "key? returns false if the given key is not present in the params" do
    assert_not @params.key?(:address)
  end

  test "keys returns an array of the keys of the params" do
    assert_equal ["person"], @params.keys
    assert_equal ["age", "name", "addresses"], @params[:person].keys
  end

  test "reject retains permitted status" do
    assert_not_predicate @params.reject { |k| k == "person" }, :permitted?
  end

  test "reject retains unpermitted status" do
    @params.permit!
    assert_predicate @params.reject { |k| k == "person" }, :permitted?
  end

  test "select retains permitted status" do
    @params.permit!
    assert_predicate @params.select { |k| k == "person" }, :permitted?
  end

  test "select retains unpermitted status" do
    assert_not_predicate @params.select { |k| k == "person" }, :permitted?
  end

  test "slice retains permitted status" do
    @params.permit!
    assert_predicate @params.slice(:person), :permitted?
  end

  test "slice retains unpermitted status" do
    assert_not_predicate @params.slice(:person), :permitted?
  end

  test "transform_keys retains permitted status" do
    @params.permit!
    assert_predicate @params.transform_keys { |k| k }, :permitted?
  end

  test "transform_keys retains unpermitted status" do
    assert_not_predicate @params.transform_keys { |k| k }, :permitted?
  end

  test "transform_values retains permitted status" do
    @params.permit!
    assert_predicate @params.transform_values { |v| v }, :permitted?
  end

  test "transform_values retains unpermitted status" do
    assert_not_predicate @params.transform_values { |v| v }, :permitted?
  end

  test "value? returns true if the given value is present in the params" do
    params = ActionController::Parameters.new(city: "Chicago", state: "Illinois")
    assert params.value?("Chicago")
  end

  test "value? returns false if the given value is not present in the params" do
    params = ActionController::Parameters.new(city: "Chicago", state: "Illinois")
    assert_not params.value?("New York")
  end

  test "values returns an array of the values of the params" do
    params = ActionController::Parameters.new(city: "Chicago", state: "Illinois")
    assert_equal ["Chicago", "Illinois"], params.values
  end

  test "values_at retains permitted status" do
    @params.permit!
    assert_predicate @params.values_at(:person).first, :permitted?
    assert_predicate @params[:person].values_at(:name).first, :permitted?
  end

  test "values_at retains unpermitted status" do
    assert_not_predicate @params.values_at(:person).first, :permitted?
    assert_not_predicate @params[:person].values_at(:name).first, :permitted?
  end

  test "is equal to Parameters instance with same params" do
    params1 = ActionController::Parameters.new(a: 1, b: 2)
    params2 = ActionController::Parameters.new(a: 1, b: 2)
    assert(params1 == params2)
  end

  test "is equal to Parameters instance with same permitted params" do
    params1 = ActionController::Parameters.new(a: 1, b: 2).permit(:a)
    params2 = ActionController::Parameters.new(a: 1, b: 2).permit(:a)
    assert(params1 == params2)
  end

  test "is equal to Parameters instance with same different source params, but same permitted params" do
    params1 = ActionController::Parameters.new(a: 1, b: 2).permit(:a)
    params2 = ActionController::Parameters.new(a: 1, c: 3).permit(:a)
    assert(params1 == params2)
    assert(params2 == params1)
  end

  test "is not equal to an unpermitted Parameters instance with same params" do
    params1 = ActionController::Parameters.new(a: 1).permit(:a)
    params2 = ActionController::Parameters.new(a: 1)
    assert(params1 != params2)
    assert(params2 != params1)
  end

  test "is not equal to Parameters instance with different permitted params" do
    params1 = ActionController::Parameters.new(a: 1, b: 2).permit(:a, :b)
    params2 = ActionController::Parameters.new(a: 1, b: 2).permit(:a)
    assert(params1 != params2)
    assert(params2 != params1)
  end

  test "equality with simple types works" do
    assert(@params != "Hello")
    assert(@params != 42)
    assert(@params != false)
  end

  test "inspect shows both class name, parameters and permitted flag" do
    assert_equal(
      '<ActionController::Parameters {"person"=>{"age"=>"32", '\
        '"name"=>{"first"=>"David", "last"=>"Heinemeier Hansson"}, ' \
        '"addresses"=>[{"city"=>"Chicago", "state"=>"Illinois"}]}} permitted: false>',
      @params.inspect
    )
  end

  test "inspect prints updated permitted flag in the output" do
    assert_match(/permitted: false/, @params.inspect)

    @params.permit!

    assert_match(/permitted: true/, @params.inspect)
  end

  if Hash.method_defined?(:dig)
    test "#dig delegates the dig method to its values" do
      assert_equal "David", @params.dig(:person, :name, :first)
      assert_equal "Chicago", @params.dig(:person, :addresses, 0, :city)
    end

    test "#dig converts hashes to parameters" do
      assert_kind_of ActionController::Parameters, @params.dig(:person)
      assert_kind_of ActionController::Parameters, @params.dig(:person, :addresses, 0)
      assert @params.dig(:person, :addresses).all? do |value|
        value.is_a?(ActionController::Parameters)
      end
    end
  else
    test "ActionController::Parameters does not respond to #dig on Ruby 2.2" do
      assert_not ActionController::Parameters.method_defined?(:dig)
      assert_not_respond_to @params, :dig
    end
  end
end
