require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

class TestController < ActionController::Base
  protect_from_forgery
  
  def render_json_nil
    render :json => nil
  end

  def render_json_hello_world
    render :json => ActiveSupport::JSON.encode(:hello => 'world')
  end

  def render_json_hello_world_with_callback
    render :json => ActiveSupport::JSON.encode(:hello => 'world'), :callback => 'alert'
  end

  def render_json_with_custom_content_type
    render :json => ActiveSupport::JSON.encode(:hello => 'world'), :content_type => 'text/javascript'
  end

  def render_symbol_json
    render :json => ActiveSupport::JSON.encode(:hello => 'world')
  end

  def render_json_with_render_to_string
    render :json => {:hello => render_to_string(:partial => 'partial')}
  end  
end

class RenderTest < ActionController::TestCase
  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger = Logger.new(nil)

    @request.host = "www.nextangle.com"
  end  
  
  def test_render_json_nil
    get :render_json_nil
    assert_equal 'null', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json
    get :render_json_hello_world
    assert_equal '{"hello":"world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_callback
    get :render_json_hello_world_with_callback
    assert_equal 'alert({"hello":"world"})', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_custom_content_type
    get :render_json_with_custom_content_type
    assert_equal '{"hello":"world"}', @response.body
    assert_equal 'text/javascript', @response.content_type
  end

  def test_render_symbol_json
    get :render_symbol_json
    assert_equal '{"hello":"world"}', @response.body
    assert_equal 'application/json', @response.content_type
  end

  def test_render_json_with_render_to_string
    get :render_json_with_render_to_string
    assert_equal '{"hello":"partial html"}', @response.body
    assert_equal 'application/json', @response.content_type
  end  
end