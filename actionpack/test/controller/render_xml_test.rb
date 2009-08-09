require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'

class TestController < ActionController::Base
  protect_from_forgery

  def render_with_location
    render :xml => "<hello/>", :location => "http://example.com", :status => 201
  end

  def render_with_object_location
    customer = Customer.new("Some guy", 1)
    render :xml => "<customer/>", :location => customer, :status => :created
  end

  def render_with_to_xml
    to_xmlable = Class.new do
      def to_xml
        "<i-am-xml/>"
      end
    end.new

    render :xml => to_xmlable
  end
  
  def formatted_xml_erb
  end
  
  def render_xml_with_custom_content_type
    render :xml => "<blah/>", :content_type => "application/atomsvc+xml"
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
  
  def test_rendering_with_location_should_set_header
    get :render_with_location
    assert_equal "http://example.com", @response.headers["Location"]
  end

  def test_rendering_xml_should_call_to_xml_if_possible
    get :render_with_to_xml
    assert_equal "<i-am-xml/>", @response.body
  end
  
  def test_rendering_with_object_location_should_set_header_with_url_for
    ActionController::Routing::Routes.draw do |map|
      map.resources :customers
      map.connect ':controller/:action/:id'
    end

    get :render_with_object_location
    assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
  end
  
  def test_should_render_formatted_xml_erb_template
    get :formatted_xml_erb, :format => :xml
    assert_equal '<test>passed formatted xml erb</test>', @response.body
  end
  
  def test_should_render_xml_but_keep_custom_content_type
    get :render_xml_with_custom_content_type
    assert_equal "application/atomsvc+xml", @response.content_type
  end
  
  def test_should_use_implicit_content_type
    get :implicit_content_type, :format => 'atom'
    assert_equal Mime::ATOM, @response.content_type
  end    
end
