# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "active_support/logger"

class RenderToStringTest < ActionController::TestCase
  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_plain_text_response_with_inline_template
      render plain: render_to_string(inline: "hello")
    end

    def render_json_response_with_partial
      render json: { hello: render_to_string(partial: "partial") }
    end

    def render_json_render_to_string
      render plain: render_to_string(json: "[]")
    end

    def test_render_json_render_to_string
      get :render_json_render_to_string
      assert_equal "[]", @response.body
    end

    def render_plain_text_response_with_inline_template_and_xml_format
      render_to_string(inline: "<language>Ruby</language>", formats: [:xml])
      render plain: "Hello"
    end

    def render_head_ok_with_inline_template_and_xml_format
      render_to_string(inline: "<language>Ruby</language>", formats: [:xml])
      head :ok
    end
  end

  tests TestController

  def test_render_plain_text_response
    get :render_plain_text_response_with_inline_template
    assert_equal "hello", @response.body
    assert_equal "text/plain", @response.media_type
  end

  def test_render_json_response
    get :render_json_response_with_partial
    assert_equal '{"hello":"partial html"}', @response.body
    assert_equal "application/json", @response.media_type
  end

  def render_json_render_to_string
    render plain: render_to_string(json: "[]")
    assert_equal "text/plain", @response.media_type
  end

  def test_response_type_does_not_change_by_render_to_string_with_xml_format
    get :render_plain_text_response_with_inline_template_and_xml_format
    assert_equal "Hello", @response.body
    assert_equal "text/plain", @response.media_type
  end

  def test_response_ok_for_render_to_string_with_xml_format
    get :render_head_ok_with_inline_template_and_xml_format
    assert_equal "text/html", @response.media_type
    assert_response :ok
  end
end
