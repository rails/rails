# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class HandleUnpermittedParamsTest < ActiveSupport::TestCase
  class HandleUnpermittedParamsTestHandler
    def self.handle_unpermitted_parameters(params:, unpermitted_keys:, request:)
      raise ActionController::UnpermittedParameters.new(unpermitted_keys)
    end
  end

  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = "HandleUnpermittedParamsTestHandler"
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted_parameters = false
  end

  test "raises on unexpected params" do
    params = ActionController::Parameters.new(
      book: { pages: 65 },
      fishing: "Turnips")

    assert_raises(ActionController::UnpermittedParameters) do
      params.permit(book: [:pages])
    end
  end

  test "raises on unexpected nested params" do
    params = ActionController::Parameters.new(
      book: { pages: 65, title: "Green Cats and where to find then." })

    assert_raises(ActionController::UnpermittedParameters) do
      params.permit(book: [:pages])
    end
  end
end
