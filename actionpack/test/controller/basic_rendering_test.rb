require 'abstract_unit'

class BasicRenderingController < ActionController::Base
  def render_hello_world
    render text: "Hello World!"
  end
end

class BasicRenderingTest < ActionController::TestCase
  tests BasicRenderingController

  def test_render_hello_world
    get :render_hello_world

    assert_equal "Hello World!", @response.body
    assert_equal "text/plain", @response.content_type
  end
end
  