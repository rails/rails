require 'abstract_unit'

# Provide some static controllers.
class BenchmarkedController < ActionController::Base
  def public_action
    render :nothing => true
  end

  def rescue_action(e)
    raise e
  end
end

class BenchmarkTest < ActionController::TestCase
  tests BenchmarkedController

  class MockLogger
    def method_missing(*args)
    end
  end

  def setup
    super
    # benchmark doesn't do anything unless a logger is set
    @controller.logger = MockLogger.new
    @request.host = "test.actioncontroller.i"
  end

  def test_with_http_1_0_request
    @request.host = nil
    assert_nothing_raised { get :public_action }
  end
end
