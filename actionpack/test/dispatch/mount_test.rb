require 'abstract_unit'

class TestRoutingMount < ActionDispatch::IntegrationTest
  Router = ActionDispatch::Routing::RouteSet.new
  Router.draw do
    SprocketsApp = lambda { |env|
      [200, {"Content-Type" => "text/html"}, ["#{env["SCRIPT_NAME"]} -- #{env["PATH_INFO"]}"]]
    }

    mount SprocketsApp, :at => "/sprockets"
    mount SprocketsApp => "/shorthand"

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

  def test_mounting_works_with_scope
    get "/its_a/sprocket/omg"
    assert_equal "/its_a/sprocket -- /omg", response.body
  end

  def test_mounting_with_shorthand
    get "/shorthand/omg"
    assert_equal "/shorthand -- /omg", response.body
  end
end