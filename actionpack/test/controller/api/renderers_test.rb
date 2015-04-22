require 'abstract_unit'
require 'active_support/core_ext/hash/conversions'

class RenderersApiController < ActionController::API
  class Model
    def to_json(options = {})
      { a: 'b' }.to_json(options)
    end

    def to_xml(options = {})
      { a: 'b' }.to_xml(options)
    end
  end

  def one
    render json: Model.new
  end

  def two
    render xml: Model.new
  end
end

class RenderersApiTest < ActionController::TestCase
  tests RenderersApiController

  def test_render_json
    get :one
    assert_response :success
    assert_equal({ a: 'b' }.to_json, @response.body)
  end

  def test_render_xml
    get :two
    assert_response :success
    assert_equal({ a: 'b' }.to_xml, @response.body)
  end
end
