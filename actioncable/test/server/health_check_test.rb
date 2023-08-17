# frozen_string_literal: true

require "test_helper"
require "active_support/core_ext/hash/indifferent_access"

class HealthCheckTest < ActionCable::TestCase
  def setup
    @config = ActionCable::Server::Configuration.new
    @config.logger = Logger.new(nil)
    @server = ActionCable::Server::Base.new config: @config
    @server.config.cable = { adapter: "async" }.with_indifferent_access

    @app = Rack::Lint.new(@server)
  end


  test "no health check app are mounted by default" do
    get "/up"
    assert_equal 404, response.first
  end

  test "setting health_check_path mount the configured health check application" do
    @server.config.health_check_path = "/up"
    get "/up"

    assert_equal 200, response.first
    assert_equal [], response.last.enum_for.to_a
  end

  test "health_check_application_can_be_customized" do
    @server.config.health_check_path = "/up"
    @server.config.health_check_application = health_check_application
    get "/up"

    assert_equal 200, response.first
    assert_equal ["Hello world!"], response.last.enum_for.to_a
  end


  private
    def get(path)
      env = Rack::MockRequest.env_for "/up", "HTTP_HOST" => "localhost"
      @response = @app.call env
    end

    attr_reader :response

    def health_check_application
      ->(env) {
        [
          200,
          { Rack::CONTENT_TYPE => "text/html" },
          ["Hello world!"],
        ]
      }
    end
end
