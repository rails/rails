# frozen_string_literal: true

require 'abstract_unit'
require 'active_support/core_ext/hash/conversions'

class MetalRenderingController < ActionController::Metal
  include AbstractController::Rendering
  include ActionController::Rendering
  include ActionController::Renderers
end

class MetalRenderingJsonController < MetalRenderingController
  class Model
    def to_json(options = {})
      { a: 'b' }.to_json(options)
    end

    def to_xml(options = {})
      { a: 'b' }.to_xml(options)
    end
  end

  use_renderers :json

  def one
    render json: Model.new
  end

  def two
    render xml: Model.new
  end
end

class RenderersMetalTest < ActionController::TestCase
  tests MetalRenderingJsonController

  def test_render_json
    get :one
    assert_response :success
    assert_equal({ a: 'b' }.to_json, @response.body)
    assert_equal 'application/json', @response.media_type
  end

  def test_render_xml
    get :two
    assert_response :success
    assert_equal(' ', @response.body)
    assert_equal 'text/plain', @response.media_type
  end
end
