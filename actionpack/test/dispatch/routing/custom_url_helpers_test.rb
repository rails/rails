require 'abstract_unit'

class TestCustomUrlHelpers < ActionDispatch::IntegrationTest
  class Linkable
    attr_reader :id

    def initialize(id)
      @id = id
    end

    def linkable_type
      self.class.name.demodulize.underscore
    end
  end

  class Category < Linkable; end
  class Collection < Linkable; end
  class Product < Linkable; end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    default_url_options host: 'www.example.com'

    root to: 'pages#index'
    get '/basket', to: 'basket#show', as: :basket

    resources :categories, :collections, :products

    namespace :admin do
      get '/dashboard', to: 'dashboard#index'
    end

    url_helper(:website)  { "http://www.rubyonrails.org" }
    url_helper(:linkable) { |linkable| [:"#{linkable.linkable_type}", { id: linkable.id }] }
    url_helper(:params)   { |params| params }
    url_helper(:symbol)   { :basket }
    url_helper(:hash)     { { controller: "basket", action: "show" } }
    url_helper(:array)    { [:admin, :dashboard] }
    url_helper(:options)  { |options| [:products, options] }
    url_helper(:defaults, size: 10) { |options| [:products, options] }
  end

  APP = build_app Routes

  def app
    APP
  end

  include Routes.url_helpers

  def setup
    @category = Category.new("1")
    @collection = Collection.new("2")
    @product = Product.new("3")
    @path_params = { 'controller' => 'pages', 'action' => 'index' }
    @unsafe_params = ActionController::Parameters.new(@path_params)
    @safe_params = ActionController::Parameters.new(@path_params).permit(:controller, :action)
  end

  def test_custom_path_helper
    assert_equal "http://www.rubyonrails.org", website_path
    assert_equal "http://www.rubyonrails.org", Routes.url_helpers.website_path

    assert_equal "/categories/1", linkable_path(@category)
    assert_equal "/categories/1", Routes.url_helpers.linkable_path(@category)
    assert_equal "/collections/2", linkable_path(@collection)
    assert_equal "/collections/2", Routes.url_helpers.linkable_path(@collection)
    assert_equal "/products/3", linkable_path(@product)
    assert_equal "/products/3", Routes.url_helpers.linkable_path(@product)

    assert_equal "/", params_path(@safe_params)
    assert_equal "/", Routes.url_helpers.params_path(@safe_params)
    assert_raises(ArgumentError) { params_path(@unsafe_params) }
    assert_raises(ArgumentError) { Routes.url_helpers.params_path(@unsafe_params) }

    assert_equal "/basket", symbol_path
    assert_equal "/basket", Routes.url_helpers.symbol_path
    assert_equal "/basket", hash_path
    assert_equal "/basket", Routes.url_helpers.hash_path
    assert_equal "/admin/dashboard", array_path
    assert_equal "/admin/dashboard", Routes.url_helpers.array_path

    assert_equal "/products?page=2", options_path(page: 2)
    assert_equal "/products?page=2", Routes.url_helpers.options_path(page: 2)
    assert_equal "/products?size=10", defaults_path
    assert_equal "/products?size=10", Routes.url_helpers.defaults_path
    assert_equal "/products?size=20", defaults_path(size: 20)
    assert_equal "/products?size=20", Routes.url_helpers.defaults_path(size: 20)
  end

  def test_custom_url_helper
    assert_equal "http://www.rubyonrails.org", website_url
    assert_equal "http://www.rubyonrails.org", Routes.url_helpers.website_url

    assert_equal "http://www.example.com/categories/1", linkable_url(@category)
    assert_equal "http://www.example.com/categories/1", Routes.url_helpers.linkable_url(@category)
    assert_equal "http://www.example.com/collections/2", linkable_url(@collection)
    assert_equal "http://www.example.com/collections/2", Routes.url_helpers.linkable_url(@collection)
    assert_equal "http://www.example.com/products/3", linkable_url(@product)
    assert_equal "http://www.example.com/products/3", Routes.url_helpers.linkable_url(@product)

    assert_equal "http://www.example.com/", params_url(@safe_params)
    assert_equal "http://www.example.com/", Routes.url_helpers.params_url(@safe_params)
    assert_raises(ArgumentError) { params_url(@unsafe_params) }
    assert_raises(ArgumentError) { Routes.url_helpers.params_url(@unsafe_params) }

    assert_equal "http://www.example.com/basket", symbol_url
    assert_equal "http://www.example.com/basket", Routes.url_helpers.symbol_url
    assert_equal "http://www.example.com/basket", hash_url
    assert_equal "http://www.example.com/basket", Routes.url_helpers.hash_url
    assert_equal "/admin/dashboard", array_path
    assert_equal "/admin/dashboard", Routes.url_helpers.array_path

    assert_equal "http://www.example.com/products?page=2", options_url(page: 2)
    assert_equal "http://www.example.com/products?page=2", Routes.url_helpers.options_url(page: 2)
    assert_equal "http://www.example.com/products?size=10", defaults_url
    assert_equal "http://www.example.com/products?size=10", Routes.url_helpers.defaults_url
    assert_equal "http://www.example.com/products?size=20", defaults_url(size: 20)
    assert_equal "http://www.example.com/products?size=20", Routes.url_helpers.defaults_url(size: 20)
  end
end
