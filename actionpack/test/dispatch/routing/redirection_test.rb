# encoding: UTF-8
require 'abstract_unit'

class TestRoutingRedirect < ActionDispatch::IntegrationTest
  class YoutubeFavoritesRedirector
    def self.call(params, request)
      "http://www.youtube.com/watch?v=#{params[:youtube_id]}"
    end
  end

  def test_redirect_argument_error
    routes = Class.new { include ActionDispatch::Routing::Redirection }.new
    assert_raises(ArgumentError) { routes.redirect Object.new }
  end

  def test_redirect_https
    draw do
      get 'secure', :to => redirect("/secure/login")
    end

    with_https do
      get '/secure'
      verify_redirect 'https://www.example.com/secure/login'
    end
  end

  def test_redirect_with_port
    draw do
      get 'account/login', :to => redirect("/login")
    end

    previous_host, self.host = self.host, 'www.example.com:3000'

    get '/account/login'
    verify_redirect 'http://www.example.com:3000/login'
  ensure
    self.host = previous_host
  end

  def test_namespace_redirect
    draw do
      namespace :private do
        root :to => redirect('/private/index')
        get "index", :to => 'private#index'
      end
    end

    get '/private'
    verify_redirect 'http://www.example.com/private/index'
  end

  def test_redirect_with_complete_url_and_status
    draw do
      get 'account/google' => redirect('http://www.google.com/', :status => 302)
    end

    get '/account/google'
    verify_redirect 'http://www.google.com/', 302
  end

  def test_login_redirect
    draw do
      get 'account/login', :to => redirect("/login")
    end

    get '/account/login'
    verify_redirect 'http://www.example.com/login'
  end

  def test_logout_redirect_without_to
    draw do
      get 'account/logout' => redirect("/logout"), :as => :logout_redirect
    end

    assert_equal '/account/logout', logout_redirect_path
    get '/account/logout'
    verify_redirect 'http://www.example.com/logout'
  end

  def test_redirect_modulo
    draw do
      get 'account/modulo/:name', :to => redirect("/%{name}s")
    end

    get '/account/modulo/name'
    verify_redirect 'http://www.example.com/names'
  end

  def test_redirect_proc
    draw do
      get 'account/proc/:name', :to => redirect {|params, req| "/#{params[:name].pluralize}" }
    end

    get '/account/proc/person'
    verify_redirect 'http://www.example.com/people'
  end

  def test_redirect_proc_with_request
    draw do
      get 'account/proc_req' => redirect {|params, req| "/#{req.method}" }
    end

    get '/account/proc_req'
    verify_redirect 'http://www.example.com/GET'
  end

  def test_redirect_hash_with_subdomain
    draw do
      get 'mobile', :to => redirect(:subdomain => 'mobile')
    end

    get '/mobile'
    verify_redirect 'http://mobile.example.com/mobile'
  end

  def test_redirect_hash_with_domain_and_path
    draw do
      get 'documentation', :to => redirect(:domain => 'example-documentation.com', :path => '')
    end

    get '/documentation'
    verify_redirect 'http://www.example-documentation.com'
  end

  def test_redirect_hash_with_path
    draw do
      get 'new_documentation', :to => redirect(:path => '/documentation/new')
    end

    get '/new_documentation'
    verify_redirect 'http://www.example.com/documentation/new'
  end

  def test_redirect_hash_with_host
    draw do
      get 'super_new_documentation', :to => redirect(:host => 'super-docs.com')
    end

    get '/super_new_documentation?section=top'
    verify_redirect 'http://super-docs.com/super_new_documentation?section=top'
  end

  def test_redirect_hash_path_substitution
    draw do
      get 'stores/:name', :to => redirect(:subdomain => 'stores', :path => '/%{name}')
    end

    get '/stores/iernest'
    verify_redirect 'http://stores.example.com/iernest'
  end

  def test_redirect_hash_path_substitution_with_catch_all
    draw do
      get 'stores/:name(*rest)', :to => redirect(:subdomain => 'stores', :path => '/%{name}%{rest}')
    end

    get '/stores/iernest/products'
    verify_redirect 'http://stores.example.com/iernest/products'
  end

  def test_redirect_class
    draw do
      get 'youtube_favorites/:youtube_id/:name', :to => redirect(YoutubeFavoritesRedirector)
    end

    get '/youtube_favorites/oHg5SJYRHA0/rick-rolld'
    verify_redirect 'http://www.youtube.com/watch?v=oHg5SJYRHA0'
  end

private

  def draw(&block)
    self.class.stub_controllers do |routes|
      routes.default_url_options = { host: 'www.example.com' }
      routes.draw(&block)
      @app = RoutedRackApp.new routes
    end
  end

  def url_for(options = {})
    @app.routes.url_helpers.url_for(options)
  end

  def with_https
    old_https = https?
    https!
    yield
  ensure
    https!(old_https)
  end

  def verify_redirect(url, status=301)
    assert_equal status, @response.status
    assert_equal url, @response.headers['Location']
    assert_equal expected_redirect_body(url), @response.body
  end

  def expected_redirect_body(url)
    %(<html><body>You are being <a href="#{ERB::Util.h(url)}">redirected</a>.</body></html>)
  end
end

class TestRedirectRouteGeneration < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      get '/account', to: redirect('/myaccount'), as: 'account'
      get '/:locale/account', to: redirect('/%{locale}/myaccount'), as: 'localized_account'
    end
  end

  APP = build_app Routes
  def app
    APP
  end

  include Routes.url_helpers

  def test_redirect_doesnt_match_unnamed_route
    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/account?controller=products', url_for(controller: 'products', action: 'index', only_path: true)
    end

    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/de/account?controller=products', url_for(controller: 'products', action: 'index', :locale => 'de', only_path: true)
    end
  end
end

class TestRedirectInterpolation < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get "/foo/:id" => redirect("/foo/bar/%{id}")
      get "/bar/:id" => redirect(:path => "/foo/bar/%{id}")
      get "/baz/:id" => redirect("/baz?id=%{id}&foo=?&bar=1#id-%{id}")
      get "/foo/bar/:id" => ok
      get "/baz" => ok
    end
  end

  APP = build_app Routes
  def app; APP end

  test "redirect escapes interpolated parameters with redirect proc" do
    get "/foo/1%3E"
    verify_redirect "http://www.example.com/foo/bar/1%3E"
  end

  test "redirect escapes interpolated parameters with option proc" do
    get "/bar/1%3E"
    verify_redirect "http://www.example.com/foo/bar/1%3E"
  end

  test "path redirect escapes interpolated parameters correctly" do
    get "/foo/1%201"
    verify_redirect "http://www.example.com/foo/bar/1%201"

    get "/baz/1%201"
    verify_redirect "http://www.example.com/baz?id=1+1&foo=?&bar=1#id-1%201"
  end

private
  def verify_redirect(url, status=301)
    assert_equal status, @response.status
    assert_equal url, @response.headers['Location']
    assert_equal expected_redirect_body(url), @response.body
  end

  def expected_redirect_body(url)
    %(<html><body>You are being <a href="#{ERB::Util.h(url)}">redirected</a>.</body></html>)
  end
end
