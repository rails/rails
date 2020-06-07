# frozen_string_literal: true

require "abstract_unit"

class LoggingTest < ActionController::TestCase
  class TestController < ActionController::Base
    log_at :debug, if: -> { params[:level] == "debug" }
    log_at :warn,  if: -> { params[:level] == "warn" }

    def show
      render plain: logger.level
    end
  end

  tests TestController

  setup do
    @logger = @controller.logger = ActiveSupport::Logger.new(nil, level: Logger::INFO)
  end

  test "logging at the default level" do
    get :show
    assert_equal Logger::INFO.to_s, response.body
  end

  test "logging at a noisier level per request" do
    assert_no_changes -> { @logger.level } do
      get :show, params: { level: "debug" }
      assert_equal Logger::DEBUG.to_s, response.body
    end
  end

  test "logging at a quieter level per request" do
    assert_no_changes -> { @logger.level } do
      get :show, params: { level: "warn" }
      assert_equal Logger::WARN.to_s, response.body
    end
  end
end
