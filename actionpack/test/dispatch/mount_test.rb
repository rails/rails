require 'abstract_unit'

class TestRoutingMount < ActionDispatch::IntegrationTest
  Router = ActionDispatch::Routing::RouteSet.new

  class FakeEngine
    def self.routes
      Object.new
    end

    def self.call(env)
      [200, {"Content-Type" => "text/html"}, ["OK"]]
    end
  end

  Router.draw do
    SprocketsApp = lambda { |env|
      [200, {"Content-Type" => "text/html"}, ["#{env["SCRIPT_NAME"]} -- #{env["PATH_INFO"]}"]]
    }

    mount SprocketsApp, :at => "/sprockets"
    mount SprocketsApp => "/shorthand"

    mount FakeEngine, :at => "/fakeengine"
    mount FakeEngine, :at => "/getfake", :via => :get

    scope "/its_a" do
      mount SprocketsApp, :at => "/sprocket"
    end
  end

  def app
    Router
  end

  def test_mounting_sets_script_name
    get "/sprockets/omg"
    assert_equal "/sprockets -- /omg", response.body
  end

  def test_mounting_works_with_nested_script_name
    get "/foo/sprockets/omg", {}, 'SCRIPT_NAME' => '/foo', 'PATH_INFO' => '/sprockets/omg'
    assert_equal "/foo/sprockets -- /omg", response.body
  end

  def test_mounting_works_with_scope
    get "/its_a/sprocket/omg"
    assert_equal "/its_a/sprocket -- /omg", response.body
  end

  def test_mounting_with_shorthand
    get "/shorthand/omg"
    assert_equal "/shorthand -- /omg", response.body
  end

  def test_mounting_works_with_via
    get "/getfake"
    assert_equal "OK", response.body

    post "/getfake"
    assert_response :not_found
  end

  def test_with_fake_engine_does_not_call_invalid_method
    get "/fakeengine"
    assert_equal "OK", response.body
  end
end
