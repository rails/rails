# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "pathname"

class RenderJSTest < ActionController::TestCase
  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_vanilla_js_hello
      render js: "alert('hello')"
    end

    def show_partial
      render partial: "partial"
    end
  end

  tests TestController

  def test_render_vanilla_js
    get :render_vanilla_js_hello, xhr: true
    assert_equal "alert('hello')", @response.body
    assert_equal "text/javascript", @response.content_type
  end

  def test_should_render_js_partial
    get :show_partial, format: "js", xhr: true
    assert_equal "partial js", @response.body
  end
end
