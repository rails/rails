require 'abstract_unit'

class ResponseBodyIsProcTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def test
      self.response_body = proc { |response, output|
        output.write 'Hello'
      }
    end
  end

  def test_simple_get
    with_test_route_set do
      assert_deprecated do
        get '/test'
      end
      assert_response :success
      assert_equal 'Hello', response.body
    end
  end

  private

    def with_test_route_set(options = {})
      with_routing do |set|
        set.draw do
          match ':action', :to => ::ResponseBodyIsProcTest::TestController
        end

        @app = self.class.build_app(set) do |middleware|
          middleware.delete "ActionDispatch::ShowExceptions"
        end

        yield
      end
    end
end
