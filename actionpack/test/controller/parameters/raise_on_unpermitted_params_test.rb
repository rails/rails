require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class RaiseOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.action_on_unpermitted = :raise
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted = false
  end

  test "raises on unexpected params" do
    params = ActionController::Parameters.new({
      book: { pages: 65 },
      fishing: "Turnips"
    })

    assert_raises(ActionController::UnexpectedParameters) do
      params.permit(book: [:pages])
    end
  end

  test "raises on unexpected nested params" do
    params = ActionController::Parameters.new({
      book: { pages: 65, title: "Green Cats and where to find then." }
    })

    assert_raises(ActionController::UnexpectedParameters) do
      params.permit(book: [:pages])
    end
  end
end