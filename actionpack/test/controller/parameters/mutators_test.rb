require "abstract_unit"
require "action_controller/metal/strong_parameters"
require "active_support/core_ext/hash/transform_values"

class ParametersMutatorsTest < ActiveSupport::TestCase
  setup do
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

  test "delete retains permitted status" do
    @params.permit!
    assert @params.delete(:person).permitted?
  end

  test "delete retains unpermitted status" do
    assert_not @params.delete(:person).permitted?
  end

  test "delete_if retains permitted status" do
    @params.permit!
    assert @params.delete_if { |k| k == "person" }.permitted?
  end

  test "delete_if retains unpermitted status" do
    assert_not @params.delete_if { |k| k == "person" }.permitted?
  end

  test "extract! retains permitted status" do
    @params.permit!
    assert @params.extract!(:person).permitted?
  end

  test "extract! retains unpermitted status" do
    assert_not @params.extract!(:person).permitted?
  end

  test "keep_if retains permitted status" do
    @params.permit!
    assert @params.keep_if { |k,v| k == "person" }.permitted?
  end

  test "keep_if retains unpermitted status" do
    assert_not @params.keep_if { |k,v| k == "person" }.permitted?
  end

  test "reject! retains permitted status" do
    @params.permit!
    assert @params.reject! { |k| k == "person" }.permitted?
  end

  test "reject! retains unpermitted status" do
    assert_not @params.reject! { |k| k == "person" }.permitted?
  end

  test "select! retains permitted status" do
    @params.permit!
    assert @params.select! { |k| k != "person" }.permitted?
  end

  test "select! retains unpermitted status" do
    assert_not @params.select! { |k| k != "person" }.permitted?
  end

  test "slice! retains permitted status" do
    @params.permit!
    assert @params.slice!(:person).permitted?
  end

  test "slice! retains unpermitted status" do
    assert_not @params.slice!(:person).permitted?
  end

  test "transform_keys! retains permitted status" do
    @params.permit!
    assert @params.transform_keys! { |k| k }.permitted?
  end

  test "transform_keys! retains unpermitted status" do
    assert_not @params.transform_keys! { |k| k }.permitted?
  end

  test "transform_values! retains permitted status" do
    @params.permit!
    assert @params.transform_values! { |v| v }.permitted?
  end

  test "transform_values! retains unpermitted status" do
    assert_not @params.transform_values! { |v| v }.permitted?
  end
end
