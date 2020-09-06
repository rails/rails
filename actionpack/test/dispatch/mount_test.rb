# frozen_string_literal: true

require 'abstract_unit'
require 'rails/engine'

class TestRoutingMount < ActionDispatch::IntegrationTest
  Router = ActionDispatch::Routing::RouteSet.new

  class AppWithRoutes < Rails::Engine
    def self.routes
      @routes ||= ActionDispatch::Routing::RouteSet.new
    end
  end

  # Test for mounting apps that respond to routes, but aren't Rails-like apps.
  class SinatraLikeApp
    def self.routes; Object.new; end

    def self.call(env)
      [200, { 'Content-Type' => 'text/html' }, ['OK']]
    end
  end

  Router.draw do
    SprocketsApp = lambda { |env|
      [200, { 'Content-Type' => 'text/html' }, ["#{env["SCRIPT_NAME"]} -- #{env["PATH_INFO"]}"]]
    }

    mount SprocketsApp, at: '/sprockets'
    mount SprocketsApp, at: '/star*'
    mount SprocketsApp => '/shorthand'

    mount SinatraLikeApp, at: '/fakeengine', as: :fake
    mount SinatraLikeApp, at: '/getfake', via: :get

    scope '/its_a' do
      mount SprocketsApp, at: '/sprocket'
    end

    resources :users do
      mount AppWithRoutes, at: '/fakeengine', as: :fake_mounted_at_resource
    end

    mount SprocketsApp, at: '/', via: :get
  end

  APP = RoutedRackApp.new Router
  def app
    APP
  end

  def test_app_name_is_properly_generated_when_engine_is_mounted_in_resources
    assert Router.mounted_helpers.method_defined?(:user_fake_mounted_at_resource),
          "A mounted helper should be defined with a parent's prefix"
    assert Router.named_routes.key?(:user_fake_mounted_at_resource),
          "A named route should be defined with a parent's prefix"
  end

  def test_mounting_at_root_path
    get '/omg'
    assert_equal ' -- /omg', response.body

    get '/~omg'
    assert_equal ' -- /~omg', response.body
  end

  def test_mounting_at_path_with_non_word_character
    get '/star*/omg'
    assert_equal '/star* -- /omg', response.body
  end

  def test_mounting_sets_script_name
    get '/sprockets/omg'
    assert_equal '/sprockets -- /omg', response.body
  end

  def test_mounting_works_with_nested_script_name
    get '/foo/sprockets/omg', headers: { 'SCRIPT_NAME' => '/foo', 'PATH_INFO' => '/sprockets/omg' }
    assert_equal '/foo/sprockets -- /omg', response.body
  end

  def test_mounting_works_with_scope
    get '/its_a/sprocket/omg'
    assert_equal '/its_a/sprocket -- /omg', response.body
  end

  def test_mounting_with_shorthand
    get '/shorthand/omg'
    assert_equal '/shorthand -- /omg', response.body
  end

  def test_mounting_does_not_match_similar_paths
    get '/shorthandomg'
    assert_not_equal '/shorthand -- /omg', response.body
    assert_equal ' -- /shorthandomg', response.body
  end

  def test_mounting_works_with_via
    get '/getfake'
    assert_equal 'OK', response.body

    post '/getfake'
    assert_response :not_found
  end

  def test_with_fake_engine_does_not_call_invalid_method
    get '/fakeengine'
    assert_equal 'OK', response.body
  end
end
