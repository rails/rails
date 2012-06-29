require 'abstract_unit'
require 'controller/fake_controllers'

class SecureArticlesController < ArticlesController; end
class BlockArticlesController < ArticlesController; end
class QueryArticlesController < ArticlesController; end

class RoutingAssertionsTest < ActionController::TestCase

  class YoutubeFavoritesRedirector
    def self.call(params, request)
      "http://www.youtube.com/watch?v=#{params[:youtube_id]}"
    end
  end

  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do

      get 'redirect' => redirect("http://thisisaredirect.org/")
      get 'redirect' => "redirect#index"
      get 'not_redirect' => "redirect#not"
      get 'not_redirect' => redirect("http://thisisnotaredirect.org/")
      get 'account/login', :to => redirect("/login")
      get 'account/logout' => redirect("/logout"), :as => :logout_redirect
      get 'account/modulo/:name', :to => redirect("/%{name}s")
      get 'account/proc/:name', :to => redirect {|params, req| "/#{params[:name].pluralize}" }
      get 'account/proc_req' => redirect {|params, req| "/#{req.method}" }
      get 'out' => redirect{|params, req| params[:to]}
      get 'mobile', :to => redirect(:subdomain => 'mobile')
      get 'documentation', :to => redirect(:subdomain => false, :domain => 'example-documentation.com', :path => '')
      get 'new_documentation', :to => redirect(:path => '/documentation/new')
      get 'super_new_documentation', :to => redirect(:host => 'super-docs.com')
      get 'stores/:name', :to => redirect(:subdomain => 'stores', :path => '/%{name}')
      get 'stores/:name(*rest)', :to => redirect(:subdomain => 'stores', :path => '/%{name}%{rest}')
      get 'youtube_favorites/:youtube_id/:name', :to => redirect(YoutubeFavoritesRedirector)
      get 'account/google' => redirect('http://www.google.com/', :status => 302)

      namespace :private do
        root to: redirect('/private/index')
      end

      resources :articles

      scope 'secure', :constraints => { :protocol => 'https://' } do
        resources :articles, :controller => 'secure_articles'
      end

      scope 'block', :constraints => lambda { |r| r.ssl? } do
        resources :articles, :controller => 'block_articles'
      end

      scope 'query', :constraints => lambda { |r| r.params[:use_query] == 'true' } do
        resources :articles, :controller => 'query_articles'
      end
    end
  end

  def test_assert_recognizes_accounts_for_redirects
    assert_raise Assertion do
      assert_recognizes({ controller: 'redirect', action: 'index' }, '/redirect')
    end
  end

  def test_assert_generates_accounts_for_redirects
    assert_raise Assertion do
      assert_generates('/redirect', { controller: 'redirect', action: 'index' })
    end
  end

  def test_assert_routing_accounts_for_redirects
    assert_raise Assertion do
      assert_routing('/redirect', { controller: 'redirect', action: 'index' })
    end
  end

  def test_assert_redirects_accounts_for_non_redirects
    assert_raise Assertion do
      assert_redirects('http://thisisnotaredirect.org/', '/not_redirect')
    end
  end

  def test_assert_redirects_with_url
    assert_redirects('http://thisisaredirect.org/', '/redirect')
  end

  def test_assert_redirects_with_to
    assert_redirects('http://example.org/login', '/account/login')
  end

  def test_assert_redirects_with_as
    assert_redirects('http://example.org/logout', @routes.url_helpers.logout_redirect_path)
  end

  def test_assert_redirects_with_namespace
    assert_redirects('http://example.org/private/index', '/private')
  end

  def test_assert_redirects_with_modulo
    assert_redirects('http://example.org/names', '/account/modulo/name')
  end

  def test_assert_redirects_with_proc
    assert_redirects('http://example.org/people', '/account/proc/people')
  end

  def test_assert_redirects_with_proc_with_request
    assert_redirects('http://example.org/GET', '/account/proc_req')
  end

  def test_assert_redirects_with_with_subdomain
    assert_redirects('http://mobile.example.org/mobile', '/mobile')
  end

  def test_assert_redirects_with_domain_and_path
    assert_redirects('http://example-documentation.com', '/documentation')
  end

  def test_assert_redirects_with_path
    assert_redirects('http://example.org/documentation/new', '/new_documentation')
  end

  def test_assert_redirects_with_host
    assert_redirects('http://super-docs.com/super_new_documentation?section=top', '/super_new_documentation?section=top')
  end

  def test_assert_redirects_with_path_substitution
    assert_redirects('http://stores.example.org/iernest', '/stores/iernest')
  end

  def test_assert_redirects_with_path_substitution_with_catch_all
    assert_redirects('http://stores.example.org/iernest/products', '/stores/iernest/products')
  end

  def test_assert_redirects_with_class
    assert_redirects('http://www.youtube.com/watch?v=oHg5SJYRHA0', '/youtube_favorites/oHg5SJYRHA0/rick-rolld')
  end

  def test_assert_redirects_with_status
    assert_raise Assertion do
      assert_redirects('http://www.google.com/', '/account/google')
    end
    assert_redirects('http://www.google.com/', '/account/google', {}, 302)
  end

  def test_assert_redirects_with_extras
    assert_redirects('http://customredirect.com/', '/out', { to: 'http://customredirect.com/' })
  end

  def test_assert_not_redirects_with_extras
    assert_raise Assertion do
      assert_not_redirects('/out', { to: 'http://customredirect.com/' })
    end
  end

  def test_assert_generates
    assert_generates('/articles', { :controller => 'articles', :action => 'index' })
    assert_generates('/articles/1', { :controller => 'articles', :action => 'show', :id => '1' })
  end

  def test_assert_generates_with_defaults
    assert_generates('/articles/1/edit', { :controller => 'articles', :action => 'edit' }, { :id => '1' })
  end

  def test_assert_generates_with_extras
    assert_generates('/articles', { :controller => 'articles', :action => 'index', :page => '1' }, {}, { :page => '1' })
  end

  def test_assert_recognizes
    assert_recognizes({ :controller => 'articles', :action => 'index' }, '/articles')
    assert_recognizes({ :controller => 'articles', :action => 'show', :id => '1' }, '/articles/1')
  end

  def test_assert_recognizes_with_extras
    assert_recognizes({ :controller => 'articles', :action => 'index', :page => '1' }, '/articles', { :page => '1' })
  end

  def test_assert_recognizes_with_method
    assert_recognizes({ :controller => 'articles', :action => 'create' }, { :path => '/articles', :method => :post })
    assert_recognizes({ :controller => 'articles', :action => 'update', :id => '1' }, { :path => '/articles/1', :method => :put })
  end

  def test_assert_recognizes_with_hash_constraint
    assert_raise(Assertion) do
      assert_recognizes({ :controller => 'secure_articles', :action => 'index' }, 'http://test.host/secure/articles')
    end
    assert_recognizes({ :controller => 'secure_articles', :action => 'index', :protocol => 'https://' }, 'https://test.host/secure/articles')
  end

  def test_assert_recognizes_with_block_constraint
    assert_raise(Assertion) do
      assert_recognizes({ :controller => 'block_articles', :action => 'index' }, 'http://test.host/block/articles')
    end
    assert_recognizes({ :controller => 'block_articles', :action => 'index' }, 'https://test.host/block/articles')
  end

  def test_assert_recognizes_with_query_constraint
    assert_raise(Assertion) do
      assert_recognizes({ :controller => 'query_articles', :action => 'index', :use_query => 'false' }, '/query/articles', { :use_query => 'false' })
    end
    assert_recognizes({ :controller => 'query_articles', :action => 'index', :use_query => 'true' }, '/query/articles', { :use_query => 'true' })
  end

  def test_assert_routing
    assert_routing('/articles', :controller => 'articles', :action => 'index')
  end

  def test_assert_routing_with_defaults
    assert_routing('/articles/1/edit', { :controller => 'articles', :action => 'edit', :id => '1' }, { :id => '1' })
  end

  def test_assert_routing_with_extras
    assert_routing('/articles', { :controller => 'articles', :action => 'index', :page => '1' }, { }, { :page => '1' })
  end

  def test_assert_routing_with_hash_constraint
    assert_raise(Assertion) do
      assert_routing('http://test.host/secure/articles', { :controller => 'secure_articles', :action => 'index' })
    end
    assert_routing('https://test.host/secure/articles', { :controller => 'secure_articles', :action => 'index', :protocol => 'https://' })
  end

  def test_assert_routing_with_block_constraint
    assert_raise(Assertion) do
      assert_routing('http://test.host/block/articles', { :controller => 'block_articles', :action => 'index' })
    end
    assert_routing('https://test.host/block/articles', { :controller => 'block_articles', :action => 'index' })
  end

  def test_with_routing
    with_routing do |routes|
      routes.draw do
        resources :articles, :path => 'artikel'
      end

      assert_routing('/artikel', :controller => 'articles', :action => 'index')
      assert_raise(Assertion) do
        assert_routing('/articles', { :controller => 'articles', :action => 'index' })
      end
    end
  end
end
