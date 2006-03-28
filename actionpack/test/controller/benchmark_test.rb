require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'

# Provide some static controllers.
class BenchmarkedController < ActionController::Base
  def public_action
    render :nothing => true
  end

  def rescue_action(e)
    raise e
  end
end

class BenchmarkTest < Test::Unit::TestCase
  class MockLogger
    def method_missing(*args)
    end
  end

  def setup
    @controller = BenchmarkedController.new
    # benchmark doesn't do anything unless a logger is set
    @controller.logger = MockLogger.new
    @request, @response = ActionController::TestRequest.new, ActionController::TestResponse.new
    @request.host = "test.actioncontroller.i"
  end

  def test_with_http_1_0_request
    @request.host = nil
    assert_nothing_raised { get :public_action }
  end
end
