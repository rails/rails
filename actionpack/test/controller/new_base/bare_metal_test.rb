require "abstract_unit"

module BareMetalTest
  class BareController < ActionController::Metal
    def index
      self.response_body = "Hello world"
    end
  end

  class BareTest < ActiveSupport::TestCase
    test "response body is a Rack-compatible response" do
      status, headers, body = BareController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal 200, status
      string = ""

      body.each do |part|
        assert part.is_a?(String), "Each part of the body must be a String"
        string << part
      end

      assert_kind_of Hash, headers, "Headers must be a Hash"
      assert headers["Content-Type"], "Content-Type must exist"

      assert_equal "Hello world", string
    end
  end

  class HeadController < ActionController::Metal
    include ActionController::Head

    def index
      head :not_found
    end
  end

  class HeadTest < ActiveSupport::TestCase
    test "head works on its own" do
      status = HeadController.action(:index).call(Rack::MockRequest.env_for("/")).first
      assert_equal 404, status
    end
  end

  class BareControllerTest < ActionController::TestCase
    test "GET index" do
      get :index
      assert_equal "Hello world", @response.body
    end
  end
end
