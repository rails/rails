require File.dirname(__FILE__) + '/../abstract_unit'

class TestLayoutController < ActionController::Base
  layout "layouts/standard"
  
  def hello_world
  end
  
  def hello_world_outside_layout
  end

  def rescue_action(e) raise end
end

class ChildWithoutTestLayoutController < TestLayoutController
  layout nil

  def hello_world
  end
end

class ChildWithOtherTestLayoutController < TestLayoutController
  layout nil

  def hello_world
  end
end

class RenderTest < Test::Unit::TestCase
  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_layout_rendering
    @request.action = "hello_world"
    response = process_request
    assert_equal "200 OK", response.headers["Status"]
    assert_equal "layouts/standard", response.template.template_name
  end


  private
    def process_request
      TestLayoutController.process(@request, @response)
    end
end