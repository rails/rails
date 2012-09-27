require 'isolation/abstract_unit'

module ApplicationTests
  class BestPracticesTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      require 'rack/test'
      extend Rack::Test::Methods
      simple_controller
    end

    def teardown
      teardown_app
    end

    test "simple controller in production mode returns best standards" do
      get '/foo'
      assert_equal "IE=Edge,chrome=1", last_response.headers["X-UA-Compatible"]
    end

    test "simple controller in development mode leaves out Chrome" do
      app("development")
      get "/foo"
      assert_equal "IE=Edge", last_response.headers["X-UA-Compatible"]
    end
  end
end
