# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"

class RenderXmlTest < ActionController::TestCase
  class XmlRenderable
    def to_xml(options)
      options[:root] ||= "i-am-xml"
      "<#{options[:root]}/>"
    end
  end

  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_with_location
      render xml: "<hello/>", location: "http://example.com", status: 201
    end

    def render_with_object_location
      customer = Customer.new("Some guy", 1)
      render xml: "<customer/>", location: customer, status: :created
    end

    def render_with_to_xml
      render xml: XmlRenderable.new
    end

    def formatted_xml_erb
    end

    def render_xml_with_custom_content_type
      render xml: "<blah/>", content_type: "application/atomsvc+xml"
    end

    def render_xml_with_custom_options
      render xml: XmlRenderable.new, root: "i-am-THE-xml"
    end
  end

  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger = ActiveSupport::Logger.new(nil)

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

  def test_rendering_xml_should_call_to_xml_with_extra_options
    get :render_xml_with_custom_options
    assert_equal "<i-am-THE-xml/>", @response.body
  end

  def test_rendering_with_object_location_should_set_header_with_url_for
    with_routing do |set|
      set.draw do
        resources :customers

        ActiveSupport::Deprecation.silence do
          get ":controller/:action"
        end
      end

      get :render_with_object_location
      assert_equal "http://www.nextangle.com/customers/1", @response.headers["Location"]
    end
  end

  def test_should_render_formatted_xml_erb_template
    get :formatted_xml_erb, format: :xml
    assert_equal "<test>passed formatted xml erb</test>", @response.body
  end

  def test_should_render_xml_but_keep_custom_content_type
    get :render_xml_with_custom_content_type
    assert_equal "application/atomsvc+xml", @response.media_type
  end

  def test_should_use_implicit_content_type
    get :implicit_content_type, format: "atom"
    assert_equal Mime[:atom], @response.media_type
  end

  def test_should_not_trigger_content_type_deprecation
    original = ActionDispatch::Response.return_only_media_type_on_content_type
    ActionDispatch::Response.return_only_media_type_on_content_type = true

    assert_not_deprecated { get :render_with_to_xml }
  ensure
    ActionDispatch::Response.return_only_media_type_on_content_type = original
  end
end
