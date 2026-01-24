# frozen_string_literal: true

require "abstract_unit"
require "rack/test"
require "minitest/mock"

class RackSilenceRequestTest < ActiveSupport::TestCase
  test "silence request only to specific path" do
    mock_logger = Minitest::Mock.new
    mock_logger.expect :silence, nil

    app = Rails::Rack::SilenceRequest.new(lambda { |env| [200, env, "app"] }, path: "/up")

    Rails.stub(:logger, mock_logger) do
      app.call(Rack::MockRequest.env_for("http://example.com/up"))
      app.call(Rack::MockRequest.env_for("http://example.com/down"))
    end

    assert mock_logger.verify
  end

  test "silence request using a Regexp" do
    mock_logger = Minitest::Mock.new
    mock_logger.expect :silence, nil

    app = Rails::Rack::SilenceRequest.new(lambda { |env| [200, env, "app"] }, path: /up/)

    Rails.stub(:logger, mock_logger) do
      app.call(Rack::MockRequest.env_for("http://example.com/up"))
      app.call(Rack::MockRequest.env_for("http://example.com/down"))
    end

    assert mock_logger.verify
  end
end
