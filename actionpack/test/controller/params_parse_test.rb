# frozen_string_literal: true

require "abstract_unit"

class ParamsParseTest < ActionController::TestCase
  class UsersController < ActionController::Base
    def create
      head :ok
    end
  end

  tests UsersController

  def test_parse_error_logged_once_when_conceal_request_body_on_parse_error_is_disabled
    with_conceal_request_body_on_parse_error_set_to(false) do
      log_output = capture_log_output do
        post :create, body: "{", as: :json
      end
      assert_equal <<~LOG, log_output
        Error occurred while parsing request parameters.
        Contents:

        {
      LOG
    end
  end

  def test_parse_error_logged_once_when_conceal_request_body_on_parse_error_is_enabled
    with_conceal_request_body_on_parse_error_set_to(true) do
      log_output = capture_log_output do
        post :create, body: "{", as: :json
      end
      assert_equal <<~LOG, log_output
        Error occurred while parsing request parameters.
      LOG
    end
  end

  private
    def capture_log_output
      output = StringIO.new
      request.set_header "action_dispatch.logger", ActiveSupport::Logger.new(output)
      yield
      output.string
    end

    def with_conceal_request_body_on_parse_error_set_to(value)
      original_value = ActionDispatch::Http::Parameters.conceal_request_body_on_parse_error
      begin
        ActionDispatch::Http::Parameters.conceal_request_body_on_parse_error = value
        yield
      ensure
        ActionDispatch::Http::Parameters.conceal_request_body_on_parse_error = original_value
      end
    end
end
