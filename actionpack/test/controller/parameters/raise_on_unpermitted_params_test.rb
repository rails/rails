# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class RaiseOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = :raise
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
      book: { pages: 65, title: "Green Cats and where to find them." })

    assert_raises(ActionController::UnpermittedParameters) do
      params.permit(book: [:pages])
    end
  end

  test "expect never raises on unexpected params" do
    params = ActionController::Parameters.new(
      id: 1,
      book: { pages: 65, title: "Green Cats and where to find them." })

    assert_nothing_raised do
      params.expect(book: [:pages])
      params.expect(book: [:pages, :title])
      params.expect(:id)
    end
  end

  test "expect! never raises on unexpected params" do
    params = ActionController::Parameters.new(
      id: 1,
      book: { pages: 65, title: "Green Cats and where to find them." })

    assert_nothing_raised do
      params.expect!(book: [:pages])
      params.expect!(book: [:pages, :title])
      params.expect!(:id)
    end
  end
end
