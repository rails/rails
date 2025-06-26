# frozen_string_literal: true

require "test_helper"

class ActiveStorage::BaseControllerTest
  class PlainController < ActiveStorage::BaseController
    def index
      self.response_body = ActiveStorage::Current.url_options.to_yaml
    end
  end

  class ScriptNameMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      request.script_name = "/foo"
      @app.call(env)
    end
  end

  class ScriptNameController < ActiveStorage::BaseController
    use ScriptNameMiddleware

    def index
      self.response_body = ActiveStorage::Current.url_options.to_yaml
    end
  end

  class TestUrlOptions < ActionDispatch::IntegrationTest
    test "host, protocol, and port are set based on the request" do
      app = PlainController.action(:index)

      result = app.call(Rack::MockRequest.env_for("http://example.com/blurgh"))
      response = YAML.load(result[2].body)

      assert_equal("http://", response[:protocol])
      assert_equal("example.com", response[:host])
      assert_equal(80, response[:port])
      assert_equal("", response[:script_name])

      result = app.call(Rack::MockRequest.env_for("https://www.example.org/blurgh"))
      response = YAML.load(result[2].body)

      assert_equal("https://", response[:protocol])
      assert_equal("www.example.org", response[:host])
      assert_equal(443, response[:port])
      assert_equal("", response[:script_name])
    end

    test "script name is set if present" do
      app = ScriptNameController.action(:index)

      result = app.call(Rack::MockRequest.env_for("http://example.com/blurgh"))
      response = YAML.load(result[2].body)

      assert_equal("http://", response[:protocol])
      assert_equal("example.com", response[:host])
      assert_equal(80, response[:port])
      assert_equal("/foo", response[:script_name])

      result = app.call(Rack::MockRequest.env_for("https://www.example.org/blurgh"))
      response = YAML.load(result[2].body)

      assert_equal("https://", response[:protocol])
      assert_equal("www.example.org", response[:host])
      assert_equal(443, response[:port])
      assert_equal("/foo", response[:script_name])
    end
  end
end
