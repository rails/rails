# frozen_string_literal: true

require 'abstract_unit'

class ParamsParseTest < ActionController::TestCase
  class UsersController < ActionController::Base
    def create
      head :ok
    end
  end

  tests UsersController

  def test_parse_error_logged_once
    log_output = capture_log_output do
      post :create, body: '{', as: :json
    end
    assert_equal <<~LOG, log_output
      Error occurred while parsing request parameters.
      Contents:

      {
    LOG
  end

  private
    def capture_log_output
      output = StringIO.new
      request.set_header 'action_dispatch.logger', ActiveSupport::Logger.new(output)
      yield
      output.string
    end
end
