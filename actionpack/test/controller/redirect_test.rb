require File.dirname(__FILE__) + '/../abstract_unit'

class RedirectTest < Test::Unit::TestCase
  class RedirectController < ActionController::Base
    def simple_redirect
      redirect_to :action => "hello_world"
    end
    
    def method_redirect
      redirect_to :dashbord_url, 1, "hello"
    end
    
    def rescue_errors(e) raise e end
    
    protected
      def dashbord_url(id, message)
        url_for :action => "dashboard", :params => { "id" => id, "message" => message }
      end
  end

  def setup
    @request  = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
  end

  def test_simple_redirect
    @request.path = "/redirect/simple_redirect"
    @request.action = "simple_redirect"
    response = process_request
    assert_equal "http://test.host/redirect/hello_world", response.headers["location"]
  end

  def test_redirect_with_method_reference_and_parameters
    @request.path = "/redirect/method_redirect"
    @request.action = "method_redirect"
    response = process_request
    assert_equal "http://test.host/redirect/dashboard?message=hello&id=1", response.headers["location"]
  end

  private
    def process_request
      RedirectController.process(@request, @response)
    end
end