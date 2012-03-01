require 'abstract_unit'
require 'controller/fake_controllers'

class SecureArticlesController < ArticlesController; end
class BlockArticlesController < ArticlesController; end
class QueryArticlesController < ArticlesController; end

class RoutingAssertionsTest < ActionController::TestCase

  def setup
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
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
    assert_raise(ActionController::RoutingError) do
      assert_recognizes({ :controller => 'secure_articles', :action => 'index' }, 'http://test.host/secure/articles')
    end
    assert_recognizes({ :controller => 'secure_articles', :action => 'index' }, 'https://test.host/secure/articles')
  end

  def test_assert_recognizes_with_block_constraint
    assert_raise(ActionController::RoutingError) do
      assert_recognizes({ :controller => 'block_articles', :action => 'index' }, 'http://test.host/block/articles')
    end
    assert_recognizes({ :controller => 'block_articles', :action => 'index' }, 'https://test.host/block/articles')
  end

  def test_assert_recognizes_with_query_constraint
    assert_raise(ActionController::RoutingError) do
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
    assert_raise(ActionController::RoutingError) do
      assert_routing('http://test.host/secure/articles', { :controller => 'secure_articles', :action => 'index' })
    end
    assert_routing('https://test.host/secure/articles', { :controller => 'secure_articles', :action => 'index' })
  end

  def test_assert_routing_with_block_constraint
    assert_raise(ActionController::RoutingError) do
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
      assert_raise(ActionController::RoutingError) do
        assert_routing('/articles', { :controller => 'articles', :action => 'index' })
      end
    end
  end
end
