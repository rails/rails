# frozen_string_literal: true

require "abstract_unit"
require "rack/test"
require "minitest/mock"

class RackSilenceRequestTest < ActiveSupport::TestCase
  test "silence request only to specific path" do
    mock_logger = Minitest::Mock.new
    mock_logger.expect :silence, nil

    app = app_with_silence(path: "/up")

    Rails.stub(:logger, mock_logger) do
      app.call(Rack::MockRequest.env_for("http://example.com/up", "REMOTE_ADDR" => "127.0.0.1"))
      app.call(Rack::MockRequest.env_for("http://example.com/down", "REMOTE_ADDR" => "127.0.0.1"))
    end

    assert mock_logger.verify
  end

  test "silence request only to specific path with ip restriction" do
    mock_logger = Minitest::Mock.new
    mock_logger.expect :silence, nil

    app = app_with_silence(path: "/up", remote_ip: "127.0.0.1")

    Rails.stub(:logger, mock_logger) do
      app.call(Rack::MockRequest.env_for("http://example.com/up", "REMOTE_ADDR" => "127.0.0.1"))
      app.call(Rack::MockRequest.env_for("http://example.com/up", "REMOTE_ADDR" => "127.0.0.2"))
    end

    assert mock_logger.verify
  end

  private
    def app_with_silence(path:, remote_ip: nil)
      Rails::Rack::SilenceRequest.new(lambda { |env| [200, env, "app"] }, path:, remote_ip:)
    end
end
