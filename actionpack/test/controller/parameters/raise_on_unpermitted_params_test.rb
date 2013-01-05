require 'abstract_unit'
require 'action_controller/metal/strong_parameters'

class RaiseOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.raise_on_unexpected = true
  end

  def teardown
    ActionController::Parameters.raise_on_unexpected = false
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