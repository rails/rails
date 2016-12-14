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
    assert @params[:person].permitted?
    assert @params[:person][:name].permitted?
  end

  test "[] retains unpermitted status" do
    assert_not @params[:person].permitted?
    assert_not @params[:person][:name].permitted?
  end

  test "as_json returns the JSON representation of the parameters hash" do
    assert_not @params.as_json.key? "parameters"
    assert_not @params.as_json.key? "permitted"
    assert @params.as_json.key? "person"
  end

  test "each carries permitted status" do
    @params.permit!
    @params.each { |key, value| assert(value.permitted?) if key == "person" }
  end

  test "each carries unpermitted status" do
    @params.each { |key, value| assert_not(value.permitted?) if key == "person" }
  end

  test "each_pair carries permitted status" do
    @params.permit!
    @params.each_pair { |key, value| assert(value.permitted?) if key == "person" }
  end

  test "each_pair carries unpermitted status" do
    @params.each_pair { |key, value| assert_not(value.permitted?) if key == "person" }
  end

  test "except retains permitted status" do
    @params.permit!
    assert @params.except(:person).permitted?
    assert @params[:person].except(:name).permitted?
  end

  test "except retains unpermitted status" do
    assert_not @params.except(:person).permitted?
    assert_not @params[:person].except(:name).permitted?
  end

  test "fetch retains permitted status" do
    @params.permit!
    assert @params.fetch(:person).permitted?
    assert @params[:person].fetch(:name).permitted?
  end

  test "fetch retains unpermitted status" do
    assert_not @params.fetch(:person).permitted?
    assert_not @params[:person].fetch(:name).permitted?
  end

  test "reject retains permitted status" do
    assert_not @params.reject { |k| k == "person" }.permitted?
  end

  test "reject retains unpermitted status" do
    @params.permit!
    assert @params.reject { |k| k == "person" }.permitted?
  end

  test "select retains permitted status" do
    @params.permit!
    assert @params.select { |k| k == "person" }.permitted?
  end

  test "select retains unpermitted status" do
    assert_not @params.select { |k| k == "person" }.permitted?
  end

  test "slice retains permitted status" do
    @params.permit!
    assert @params.slice(:person).permitted?
  end

  test "slice retains unpermitted status" do
    assert_not @params.slice(:person).permitted?
  end

  test "transform_keys retains permitted status" do
    @params.permit!
    assert @params.transform_keys { |k| k }.permitted?
  end

  test "transform_keys retains unpermitted status" do
    assert_not @params.transform_keys { |k| k }.permitted?
  end

  test "transform_values retains permitted status" do
    @params.permit!
    assert @params.transform_values { |v| v }.permitted?
  end

  test "transform_values retains unpermitted status" do
    assert_not @params.transform_values { |v| v }.permitted?
  end

  test "values_at retains permitted status" do
    @params.permit!
    assert @params.values_at(:person).first.permitted?
    assert @params[:person].values_at(:name).first.permitted?
  end

  test "values_at retains unpermitted status" do
    assert_not @params.values_at(:person).first.permitted?
    assert_not @params[:person].values_at(:name).first.permitted?
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
      assert_not @params.respond_to?(:dig)
    end
  end
end
