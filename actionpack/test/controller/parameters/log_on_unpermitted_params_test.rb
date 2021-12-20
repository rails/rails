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

  test "logs on unexpected nested params with require" do
    request_params = { book: { pages: 65, title: "Green Cats and where to find then.", author: "G. A. Dog" } }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :title, :author. Context: { action: my_action, controller: my_controller }") do
      params.require(:book).permit(:pages)
    end
  end

  test "logs on unexpected param with deep_dup" do
    request_params = { book: { pages: 3, author: "YY" } }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :author. Context: { action: my_action, controller: my_controller }") do
      params.deep_dup.permit(book: [:pages])
    end
  end

  test "logs on unexpected params with slice" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car. Context: { action: my_action, controller: my_controller }") do
      params.slice(:food, :fishing, :car).permit(:food)
    end
  end

  test "logs on unexpected params with except" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car. Context: { action: my_action, controller: my_controller }") do
      params.except(:music).permit(:food)
    end
  end

  test "logs on unexpected params with extract!" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car. Context: { action: my_action, controller: my_controller }") do
      params.extract!(:food, :fishing, :car).permit(:food)
    end

    assert_logged("Unpermitted parameter: :music. Context: { action: my_action, controller: my_controller }") do
      params.permit(:food)
    end
  end

  test "logs on unexpected params with transform_values" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car, :music. Context: { action: my_action, controller: my_controller }") do
      params.transform_values { |v| v.upcase }.permit(:food)
    end
  end

  test "logs on unexpected params with transform_keys" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :FISHING, :CAR, :MUSIC. Context: { action: my_action, controller: my_controller }") do
      params.transform_keys { |k| k.upcase }.permit(:FOOD)
    end
  end

  test "logs on unexpected param with deep_transform_keys" do
    request_params = { book: { pages: 48, title: "Hope" } }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :TITLE. Context: { action: my_action, controller: my_controller }") do
      params.deep_transform_keys { |k| k.upcase }.permit(BOOK: [:PAGES])
    end
  end

  test "logs on unexpected param with select" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :music. Context: { action: my_action, controller: my_controller }") do
      params.select { |k| k == "music" }.permit(:food)
    end
  end

  test "logs on unexpected params with reject" do
    request_params = { food: "tomato", fishing: "Turnips", car: "Mercedes", music: "No. 9" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameters: :fishing, :car. Context: { action: my_action, controller: my_controller }") do
      params.reject { |k| k == "music" }.permit(:food)
    end
  end

  test "logs on unexpected param with compact" do
    request_params = { food: "tomato", fishing: "Turnips", car: nil, music: nil }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :fishing. Context: { action: my_action, controller: my_controller }") do
      params.compact.permit(:food)
    end
  end

  test "logs on unexpected param with merge" do
    request_params = { food: "tomato" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :album. Context: { action: my_action, controller: my_controller }") do
      params.merge(album: "My favorites").permit(:food)
    end
  end

  test "logs on unexpected param with reverse_merge" do
    request_params = { food: "tomato" }
    context = { "action" => "my_action", "controller" => "my_controller" }
    params = ActionController::Parameters.new(request_params, context)

    assert_logged("Unpermitted parameter: :album. Context: { action: my_action, controller: my_controller }") do
      params.reverse_merge(album: "My favorites").permit(:food)
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
