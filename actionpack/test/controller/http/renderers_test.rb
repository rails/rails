require 'abstract_unit'

class Model
  def to_json(options = {})
    { :a => 'b' }.to_json(options)
  end

  def to_xml(options = {})
    { :a => 'b' }.to_xml(options)
  end
end

class RenderersHTTPController < ActionController::HTTP
  def one
    render :json => Model.new
  end

  def two
    render :xml => Model.new
  end
end

class RenderersHTTPTest < ActionController::TestCase
  tests RenderersHTTPController

  def test_render_json
    get :one
    assert_response :success
    assert_equal({ :a => 'b' }.to_json, @response.body)
  end

  def test_render_xml
    get :two
    assert_response :success
    assert_equal({ :a => 'b' }.to_xml, @response.body)
  end
end
