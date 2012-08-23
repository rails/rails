require 'abstract_unit'

class CustomExceptionHandlerParamsParsingTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def parse
      head :ok
    end
  end

  def self.build_app(routes = nil)
    custom_error_handler = lambda { |e| [400, {}, ["Bad Request"]]}

    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use "ActionDispatch::ShowExceptions", ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
      middleware.use "ActionDispatch::DebugExceptions"
      middleware.use "ActionDispatch::Callbacks"
      middleware.use "ActionDispatch::ParamsParser", {}, custom_error_handler
      middleware.use "ActionDispatch::Cookies"
      middleware.use "ActionDispatch::Flash"
      middleware.use "Rack::Head"
    end
  end

  self.app = build_app

  test "calls provided exception handler if parsing unsuccessful" do
    with_test_routing do
      begin
        $stderr = StringIO.new # suppress the log
        json = "[\"person]\": {\"name\": \"David\"}}"
        post "/parse", json, {'CONTENT_TYPE' => 'application/json', 'action_dispatch.show_exceptions' => false}
        assert_response :bad_request
      ensure
        $stderr = STDERR
      end
    end
  end


  private
    def with_test_routing
      with_routing do |set|
        set.draw do
          post ':action', :to => ::CustomExceptionHandlerParamsParsingTest::TestController
        end
        yield
      end
    end
end
