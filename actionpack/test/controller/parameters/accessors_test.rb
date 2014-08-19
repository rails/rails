require 'abstract_unit'
require 'action_controller/metal/strong_parameters'
require 'active_support/core_ext/hash/transform_values'

class ParametersAccessorsTest < ActiveSupport::TestCase
  setup do
    @params = ActionController::Parameters.new(
      person: {
        age: '32',
        name: {
          first: 'David',
          last: 'Heinemeier Hansson'
        },
        addresses: [{city: 'Chicago', state: 'Illinois'}]
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
end
