# frozen_string_literal: true

require "test_helper"

class ActiveStorage::BaseControllerTest
  class PlainController < ActiveStorage::BaseController
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

      result = app.call(Rack::MockRequest.env_for("https://www.example.org/blurgh"))
      response = YAML.load(result[2].body)

      assert_equal("https://", response[:protocol])
      assert_equal("www.example.org", response[:host])
      assert_equal(443, response[:port])
    end
  end
end
