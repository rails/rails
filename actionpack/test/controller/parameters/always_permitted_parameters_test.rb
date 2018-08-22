# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class AlwaysPermittedParametersTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = :raise
    ActionController::Parameters.always_permitted_parameters = %w( controller action format )
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted_parameters = false
    ActionController::Parameters.always_permitted_parameters = %w( controller action )
  end

  test "returns super on missing constant other than NEVER_UNPERMITTED_PARAMS" do
    ActionController::Parameters.superclass.stub :const_missing, "super" do
      assert_equal "super", ActionController::Parameters::NON_EXISTING_CONSTANT
    end
  end

  test "permits parameters that are allowlisted" do
    params = ActionController::Parameters.new(
      book: { pages: 65 },
      format: "json")
    permitted = params.permit book: [:pages]
    assert_predicate permitted, :permitted?
  end
end
