# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "active_support/logger"

class RenderJsonTest < ActionController::TestCase
  class JsonRenderable
    def as_json(options = {})
      hash = { a: :b, c: :d, e: :f }
      hash.except!(*options[:except]) if options[:except]
      hash
    end

    def to_json(options = {})
      super except: [:c, :e]
    end
  end

  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_json_nil
      render json: nil
    end

    def render_json_render_to_string
      render plain: render_to_string(json: "[]")
    end

    def render_json_hello_world
      render json: ActiveSupport::JSON.encode(hello: "world")
    end

    def render_json_hello_world_with_status
      render json: ActiveSupport::JSON.encode(hello: "world"), status: 401
    end

    def render_json_hello_world_with_callback
      render json: ActiveSupport::JSON.encode(hello: "world"), callback: "alert"
    end

    def render_json_with_custom_content_type
      render json: ActiveSupport::JSON.encode(hello: "world"), content_type: "text/javascript"
    end

    def render_symbol_json
      render json: ActiveSupport::JSON.encode(hello: "world")
    end

    def render_json_with_render_to_string
      render json: { hello: render_to_string(partial: "partial") }
    end

    def render_json_with_extra_options
      render json: JsonRenderable.new, except: [:c, :e]
    end

    def render_json_without_options
      render json: JsonRenderable.new
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

  def test_render_json_nil
    get :render_json_nil
    assert_equal "null", @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_render_to_string
    get :render_json_render_to_string
    assert_equal "[]", @response.body
  end

  def test_render_json
    get :render_json_hello_world
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_with_status
    get :render_json_hello_world_with_status
    assert_equal '{"hello":"world"}', @response.body
    assert_equal 401, @response.status
  end

  def test_render_json_with_callback
    get :render_json_hello_world_with_callback, xhr: true
    assert_equal '/**/alert({"hello":"world"})', @response.body
    assert_equal "text/javascript", @response.media_type
  end

  def test_render_json_with_custom_content_type
    get :render_json_with_custom_content_type, xhr: true
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "text/javascript", @response.media_type
  end

  def test_render_symbol_json
    get :render_symbol_json
    assert_equal '{"hello":"world"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_with_render_to_string
    get :render_json_with_render_to_string
    assert_equal '{"hello":"partial html"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_forwards_extra_options
    get :render_json_with_extra_options
    assert_equal '{"a":"b"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def test_render_json_calls_to_json_from_object
    get :render_json_without_options
    assert_equal '{"a":"b"}', @response.body
  end

  def test_should_not_trigger_content_type_deprecation
    original = ActionDispatch::Response.return_only_media_type_on_content_type
    ActionDispatch::Response.return_only_media_type_on_content_type = true

    assert_not_deprecated { get :render_json_hello_world }
  ensure
    ActionDispatch::Response.return_only_media_type_on_content_type = original
  end

  def test_should_not_trigger_content_type_deprecation_with_callback
    original = ActionDispatch::Response.return_only_media_type_on_content_type
    ActionDispatch::Response.return_only_media_type_on_content_type = true

    assert_not_deprecated { get :render_json_hello_world_with_callback, xhr: true }
  ensure
    ActionDispatch::Response.return_only_media_type_on_content_type = original
  end
end
