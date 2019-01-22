# frozen_string_literal: true

require "test_helper"
require "stubs/test_server"

class ActionCable::Connection::RescuableTest < ActionCable::TestCase
  class Connection < ActionCable::Connection::Base
    class CustomError < StandardError; end
    class ConnectError < CustomError; end
    class DisconnectError < CustomError; end

    attr_reader :last_exception

    rescue_from CustomError do |exception|
      @last_exception = exception
    end

    def connect
      raise ConnectError
    end

    def disconnect
      raise DisconnectError
    end

    def send_async(method, *args)
      send method, *args
    end
  end

  setup do
    @server = TestServer.new
    @server.config.allowed_request_origins = %w( http://rubyonrails.com )
  end

  test "on connection open" do
    connection = open_connection
    connection.send :handle_open

    assert_instance_of Connection::ConnectError, connection.last_exception
  end

  test "on connection close" do
    connection = open_connection
    connection.send :handle_close

    assert_instance_of Connection::DisconnectError, connection.last_exception
  end

  private
    def open_connection
      env = Rack::MockRequest.env_for "/test", "HTTP_CONNECTION" => "upgrade", "HTTP_UPGRADE" => "websocket",
        "HTTP_HOST" => "localhost", "HTTP_ORIGIN" => "http://rubyonrails.com"

      Connection.new(@server, env)
    end
end
