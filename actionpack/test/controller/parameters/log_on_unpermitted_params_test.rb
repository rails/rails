# frozen_string_literal: true

require "abstract_unit"
require "action_controller/metal/strong_parameters"

class LogOnUnpermittedParamsTest < ActiveSupport::TestCase
  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = :log
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted_parameters = false
  end

  test "logs on unexpected param" do
    request_params = { book: { pages: 65 }, fishing: "Turnips" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :fishing. Context: { action: my_action, controller: my_controller }") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected params" do
    request_params = { book: { pages: 65 }, fishing: "Turnips", car: "Mercedes" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car. Context: { action: my_action, controller: my_controller }") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected nested param" do
    params = ActionController::Parameters.new(
      book: { pages: 65, title: "Green Cats and where to find then." })

    assert_logged("Unpermitted parameter: :title. Context: {  }") do
      params.permit(book: [:pages])
    end
  end

  test "logs on unexpected nested params" do
    params = ActionController::Parameters.new(
      book: { pages: 65, title: "Green Cats and where to find then.", author: "G. A. Dog" })

    assert_logged("Unpermitted parameters: :title, :author. Context: {  }") do
      params.permit(book: [:pages])
    end
  end

  private
    def assert_logged(message)
      old_logger = ActionController::Base.logger
      log = StringIO.new
      ActionController::Base.logger = Logger.new(log)

      begin
        yield

        log.rewind
        assert_match message, log.read
      ensure
        ActionController::Base.logger = old_logger
      end
    end
end
