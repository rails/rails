require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

class TestController < ActionController::Base
  protect_from_forgery

  def render_vanilla_js_hello
    render :js => "alert('hello')"
  end
  
  def greeting
    # let's just rely on the template
  end
  
  def partial
    render :partial => 'partial'
  end  
end

class RenderTest < ActionController::TestCase
  tests TestController

  def test_render_vanilla_js
    get :render_vanilla_js_hello
    assert_equal "alert('hello')", @response.body
    assert_equal "text/javascript", @response.content_type
  end
  
  def test_render_with_default_from_accept_header
    xhr :get, :greeting
    assert_equal "$(\"body\").visualEffect(\"highlight\");", @response.body
  end
  
  def test_should_render_js_partial
    xhr :get, :partial, :format => 'js'
    assert_equal 'partial js', @response.body
  end  
end