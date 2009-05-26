require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

class TestController < ActionController::Base
  protect_from_forgery
  layout :determine_layout

  module RenderTestHelper
    def rjs_helper_method_from_module
      page.visual_effect :highlight
    end
  end

  helper RenderTestHelper
  helper do
    def rjs_helper_method(value)
      page.visual_effect :highlight, value
    end
  end

  def enum_rjs_test
    render :update do |page|
      page.select('.product').each do |value|
        page.rjs_helper_method_from_module
        page.rjs_helper_method(value)
        page.sortable(value, :url => { :action => "order" })
        page.draggable(value)
      end
    end
  end
  
  def render_explicit_html_template
  end
  
  def render_custom_code_rjs
    render :update, :status => 404 do |page|
      page.replace :foo, :partial => 'partial'
    end
  end
  
  def render_implicit_html_template
  end
  
  def render_js_with_explicit_template
    @project_id = 4
    render :template => 'test/delete_with_js'
  end

  def render_js_with_explicit_action_template
    @project_id = 4
    render :action => 'delete_with_js'
  end
  
  def delete_with_js
    @project_id = 4
  end
  
  def update_page
    render :update do |page|
      page.replace_html 'balance', '$37,000,000.00'
      page.visual_effect :highlight, 'balance'
    end
  end

  def update_page_with_instance_variables
    @money = '$37,000,000.00'
    @div_id = 'balance'
    render :update do |page|
      page.replace_html @div_id, @money
      page.visual_effect :highlight, @div_id
    end
  end

  def update_page_with_view_method
    render :update do |page|
      page.replace_html 'person', pluralize(2, 'person')
    end
  end
  
  def partial_as_rjs
    render :update do |page|
      page.replace :foo, :partial => 'partial'
    end
  end

  def respond_to_partial_as_rjs
    respond_to do |format|
      format.js do
        render :update do |page|
          page.replace :foo, :partial => 'partial'
        end
      end
    end
  end
  
  def render_alternate_default
    # For this test, the method "default_render" is overridden:
    @alternate_default_render = lambda do
      render :update do |page|
        page.replace :foo, :partial => 'partial'
      end
    end
  end  
  
private
  def default_render
    if @alternate_default_render
      @alternate_default_render.call
    else
      super
    end
  end

  def determine_layout
    case action_name
      when "hello_world", "layout_test", "rendering_without_layout",
           "rendering_nothing_on_layout", "render_text_hello_world",
           "render_text_hello_world_with_layout",
           "hello_world_with_layout_false",
           "partial_only", "partial_only_with_layout",
           "accessing_params_in_template",
           "accessing_params_in_template_with_layout",
           "render_with_explicit_template",
           "render_with_explicit_string_template",
           "update_page", "update_page_with_instance_variables"

        "layouts/standard"
      when "action_talk_to_layout", "layout_overriding_layout"
        "layouts/talk_from_action"
      when "render_implicit_html_template_from_xhr_request"
        (request.xhr? ? 'layouts/xhr' : 'layouts/standard')
    end
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
  
  def test_enum_rjs_test
    ActiveSupport::SecureRandom.stubs(:base64).returns("asdf")
    get :enum_rjs_test
    body = %{
      $$(".product").each(function(value, index) {
      new Effect.Highlight(element,{});
      new Effect.Highlight(value,{});
      Sortable.create(value, {onUpdate:function(){new Ajax.Request('/test/order', {asynchronous:true, evalScripts:true, parameters:Sortable.serialize(value) + '&authenticity_token=' + encodeURIComponent('asdf')})}});
      new Draggable(value, {});
      });
    }.gsub(/^      /, '').strip
    assert_equal body, @response.body
  end
  
  def test_explicitly_rendering_an_html_template_with_implicit_html_template_renders_should_be_possible_from_an_rjs_template
    [:js, "js"].each do |format|
      assert_nothing_raised do
        get :render_explicit_html_template, :format => format
        assert_equal %(document.write("Hello world\\n");), @response.body
      end
    end
  end 
  
  def test_render_custom_code_rjs
    get :render_custom_code_rjs
    assert_response 404
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end
  
  def test_render_in_an_rjs_template_should_pick_html_templates_when_available
    [:js, "js"].each do |format|
      assert_nothing_raised do
        get :render_implicit_html_template, :format => format
        assert_equal %(document.write("Hello world\\n");), @response.body
      end
    end
  end
  
  def test_render_rjs_template_explicitly
    get :render_js_with_explicit_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end

  def test_rendering_rjs_action_explicitly
    get :render_js_with_explicit_action_template
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end
  
  def test_render_rjs_with_default
    get :delete_with_js
    assert_equal %!Element.remove("person");\nnew Effect.Highlight(\"project-4\",{});!, @response.body
  end
  
  def test_update_page
    get :update_page
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers['Content-Type']
    assert_equal 2, @response.body.split($/).length
  end

  def test_update_page_with_instance_variables
    get :update_page_with_instance_variables
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers["Content-Type"]
    assert_match /balance/, @response.body
    assert_match /\$37/, @response.body
  end

  def test_update_page_with_view_method
    get :update_page_with_view_method
    assert_template nil
    assert_equal 'text/javascript; charset=utf-8', @response.headers["Content-Type"]
    assert_match /2 people/, @response.body
  end  
  
  def test_should_render_html_formatted_partial_with_rjs
    xhr :get, :partial_as_rjs
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end

  def test_should_render_html_formatted_partial_with_rjs_and_js_format
    xhr :get, :respond_to_partial_as_rjs
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end
  
  def test_should_render_with_alternate_default_render
    xhr :get, :render_alternate_default
    assert_equal %(Element.replace("foo", "partial html");), @response.body
  end  
end