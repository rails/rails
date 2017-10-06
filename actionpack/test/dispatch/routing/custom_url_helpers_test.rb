# frozen_string_literal: true

require "abstract_unit"

class TestCustomUrlHelpers < ActionDispatch::IntegrationTest
  class Linkable
    attr_reader :id

    def self.name
      super.demodulize
    end

    def initialize(id)
      @id = id
    end

    def linkable_type
      self.class.name.underscore
    end
  end

  class Category < Linkable; end
  class Collection < Linkable; end
  class Product < Linkable; end
  class Manufacturer < Linkable; end

  class Model
    extend ActiveModel::Naming
    include ActiveModel::Conversion

    attr_reader :id

    def initialize(id = nil)
      @id = id
    end

    remove_method :model_name
    def model_name
      @_model_name ||= ActiveModel::Name.new(self.class, nil, self.class.name.demodulize)
    end

    def persisted?
      false
    end
  end

  class Basket < Model; end
  class User < Model; end
  class Video < Model; end

  class Article
    attr_reader :id

    def self.name
      "Article"
    end

    def initialize(id)
      @id = id
    end
  end

  class Page
    attr_reader :id

    def self.name
      super.demodulize
    end

    def initialize(id)
      @id = id
    end
  end

  class CategoryPage < Page; end
  class ProductPage < Page; end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    default_url_options host: "www.example.com"

    root to: "pages#index"
    get "/basket", to: "basket#show", as: :basket
    get "/posts/:id", to: "posts#show", as: :post
    get "/profile", to: "users#profile", as: :profile
    get "/media/:id", to: "media#show", as: :media
    get "/pages/:id", to: "pages#show", as: :page

    resources :categories, :collections, :products, :manufacturers

    namespace :admin do
      get "/dashboard", to: "dashboard#index"
    end

    direct(:website)  { "http://www.rubyonrails.org" }
    direct("string")  { "http://www.rubyonrails.org" }
    direct(:helper)   { basket_url }
    direct(:linkable) { |linkable| [:"#{linkable.linkable_type}", { id: linkable.id }] }
    direct(:nested)   { |linkable| route_for(:linkable, linkable) }
    direct(:params)   { |params| params }
    direct(:symbol)   { :basket }
    direct(:hash)     { { controller: "basket", action: "show" } }
    direct(:array)    { [:admin, :dashboard] }
    direct(:options)  { |options| [:products, options] }
    direct(:defaults, size: 10) { |options| [:products, options] }

    direct(:browse, page: 1, size: 10) do |options|
      [:products, options.merge(params.permit(:page, :size).to_h.symbolize_keys)]
    end

    resolve("Article") { |article| [:post, { id: article.id }] }
    resolve("Basket") { |basket| [:basket] }
    resolve("Manufacturer") { |manufacturer| route_for(:linkable, manufacturer) }
    resolve("User", anchor: "details") { |user, options| [:profile, options] }
    resolve("Video") { |video| [:media, { id: video.id }] }
    resolve(%w[Page CategoryPage ProductPage]) { |page| [:page, { id: page.id }] }
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
    @manufacturer = Manufacturer.new("apple")
    @basket = Basket.new
    @user = User.new
    @video = Video.new("4")
    @article = Article.new("5")
    @page = Page.new("6")
    @category_page = CategoryPage.new("7")
    @product_page = ProductPage.new("8")
    @path_params = { "controller" => "pages", "action" => "index" }
    @unsafe_params = ActionController::Parameters.new(@path_params)
    @safe_params = ActionController::Parameters.new(@path_params).permit(:controller, :action)
  end

  def params
    ActionController::Parameters.new(page: 2, size: 25)
  end

  def test_direct_paths
    assert_equal "/", website_path
    assert_equal "/", Routes.url_helpers.website_path

    assert_equal "/", string_path
    assert_equal "/", Routes.url_helpers.string_path

    assert_equal "/basket", helper_path
    assert_equal "/basket", Routes.url_helpers.helper_path

    assert_equal "/categories/1", linkable_path(@category)
    assert_equal "/categories/1", Routes.url_helpers.linkable_path(@category)
    assert_equal "/collections/2", linkable_path(@collection)
    assert_equal "/collections/2", Routes.url_helpers.linkable_path(@collection)
    assert_equal "/products/3", linkable_path(@product)
    assert_equal "/products/3", Routes.url_helpers.linkable_path(@product)

    assert_equal "/categories/1", nested_path(@category)
    assert_equal "/categories/1", Routes.url_helpers.nested_path(@category)

    assert_equal "/", params_path(@safe_params)
    assert_equal "/", Routes.url_helpers.params_path(@safe_params)
    assert_raises(ActionController::UnfilteredParameters) { params_path(@unsafe_params) }
    assert_raises(ActionController::UnfilteredParameters) { Routes.url_helpers.params_path(@unsafe_params) }

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

    assert_equal "/products?page=2&size=25", browse_path
    assert_raises(NameError) { Routes.url_helpers.browse_path }
  end

  def test_direct_urls
    assert_equal "http://www.rubyonrails.org", website_url
    assert_equal "http://www.rubyonrails.org", Routes.url_helpers.website_url

    assert_equal "http://www.rubyonrails.org", string_url
    assert_equal "http://www.rubyonrails.org", Routes.url_helpers.string_url

    assert_equal "http://www.example.com/basket", helper_url
    assert_equal "http://www.example.com/basket", Routes.url_helpers.helper_url

    assert_equal "http://www.example.com/categories/1", linkable_url(@category)
    assert_equal "http://www.example.com/categories/1", Routes.url_helpers.linkable_url(@category)
    assert_equal "http://www.example.com/collections/2", linkable_url(@collection)
    assert_equal "http://www.example.com/collections/2", Routes.url_helpers.linkable_url(@collection)
    assert_equal "http://www.example.com/products/3", linkable_url(@product)
    assert_equal "http://www.example.com/products/3", Routes.url_helpers.linkable_url(@product)

    assert_equal "http://www.example.com/categories/1", nested_url(@category)
    assert_equal "http://www.example.com/categories/1", Routes.url_helpers.nested_url(@category)

    assert_equal "http://www.example.com/", params_url(@safe_params)
    assert_equal "http://www.example.com/", Routes.url_helpers.params_url(@safe_params)
    assert_raises(ActionController::UnfilteredParameters) { params_url(@unsafe_params) }
    assert_raises(ActionController::UnfilteredParameters) { Routes.url_helpers.params_url(@unsafe_params) }

    assert_equal "http://www.example.com/basket", symbol_url
    assert_equal "http://www.example.com/basket", Routes.url_helpers.symbol_url
    assert_equal "http://www.example.com/basket", hash_url
    assert_equal "http://www.example.com/basket", Routes.url_helpers.hash_url
    assert_equal "http://www.example.com/admin/dashboard", array_url
    assert_equal "http://www.example.com/admin/dashboard", Routes.url_helpers.array_url

    assert_equal "http://www.example.com/products?page=2", options_url(page: 2)
    assert_equal "http://www.example.com/products?page=2", Routes.url_helpers.options_url(page: 2)
    assert_equal "http://www.example.com/products?size=10", defaults_url
    assert_equal "http://www.example.com/products?size=10", Routes.url_helpers.defaults_url
    assert_equal "http://www.example.com/products?size=20", defaults_url(size: 20)
    assert_equal "http://www.example.com/products?size=20", Routes.url_helpers.defaults_url(size: 20)

    assert_equal "http://www.example.com/products?page=2&size=25", browse_url
    assert_raises(NameError) { Routes.url_helpers.browse_url }
  end

  def test_resolve_paths
    assert_equal "/basket", polymorphic_path(@basket)
    assert_equal "/basket", Routes.url_helpers.polymorphic_path(@basket)

    assert_equal "/profile#details", polymorphic_path(@user)
    assert_equal "/profile#details", Routes.url_helpers.polymorphic_path(@user)

    assert_equal "/profile#password", polymorphic_path(@user, anchor: "password")
    assert_equal "/profile#password", Routes.url_helpers.polymorphic_path(@user, anchor: "password")

    assert_equal "/media/4", polymorphic_path(@video)
    assert_equal "/media/4", Routes.url_helpers.polymorphic_path(@video)
    assert_equal "/media/4", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.path.handle_model_call(self, @video)

    assert_equal "/posts/5", polymorphic_path(@article)
    assert_equal "/posts/5", Routes.url_helpers.polymorphic_path(@article)
    assert_equal "/posts/5", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.path.handle_model_call(self, @article)

    assert_equal "/pages/6", polymorphic_path(@page)
    assert_equal "/pages/6", Routes.url_helpers.polymorphic_path(@page)
    assert_equal "/pages/6", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.path.handle_model_call(self, @page)

    assert_equal "/pages/7", polymorphic_path(@category_page)
    assert_equal "/pages/7", Routes.url_helpers.polymorphic_path(@category_page)
    assert_equal "/pages/7", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.path.handle_model_call(self, @category_page)

    assert_equal "/pages/8", polymorphic_path(@product_page)
    assert_equal "/pages/8", Routes.url_helpers.polymorphic_path(@product_page)
    assert_equal "/pages/8", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.path.handle_model_call(self, @product_page)

    assert_equal "/manufacturers/apple", polymorphic_path(@manufacturer)
    assert_equal "/manufacturers/apple", Routes.url_helpers.polymorphic_path(@manufacturer)
  end

  def test_resolve_urls
    assert_equal "http://www.example.com/basket", polymorphic_url(@basket)
    assert_equal "http://www.example.com/basket", Routes.url_helpers.polymorphic_url(@basket)
    assert_equal "http://www.example.com/basket", polymorphic_url(@basket)
    assert_equal "http://www.example.com/basket", Routes.url_helpers.polymorphic_url(@basket)

    assert_equal "http://www.example.com/profile#details", polymorphic_url(@user)
    assert_equal "http://www.example.com/profile#details", Routes.url_helpers.polymorphic_url(@user)

    assert_equal "http://www.example.com/profile#password", polymorphic_url(@user, anchor: "password")
    assert_equal "http://www.example.com/profile#password", Routes.url_helpers.polymorphic_url(@user, anchor: "password")

    assert_equal "http://www.example.com/media/4", polymorphic_url(@video)
    assert_equal "http://www.example.com/media/4", Routes.url_helpers.polymorphic_url(@video)
    assert_equal "http://www.example.com/media/4", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.url.handle_model_call(self, @video)

    assert_equal "http://www.example.com/posts/5", polymorphic_url(@article)
    assert_equal "http://www.example.com/posts/5", Routes.url_helpers.polymorphic_url(@article)
    assert_equal "http://www.example.com/posts/5", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.url.handle_model_call(self, @article)

    assert_equal "http://www.example.com/pages/6", polymorphic_url(@page)
    assert_equal "http://www.example.com/pages/6", Routes.url_helpers.polymorphic_url(@page)
    assert_equal "http://www.example.com/pages/6", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.url.handle_model_call(self, @page)

    assert_equal "http://www.example.com/pages/7", polymorphic_url(@category_page)
    assert_equal "http://www.example.com/pages/7", Routes.url_helpers.polymorphic_url(@category_page)
    assert_equal "http://www.example.com/pages/7", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.url.handle_model_call(self, @category_page)

    assert_equal "http://www.example.com/pages/8", polymorphic_url(@product_page)
    assert_equal "http://www.example.com/pages/8", Routes.url_helpers.polymorphic_url(@product_page)
    assert_equal "http://www.example.com/pages/8", ActionDispatch::Routing::PolymorphicRoutes::HelperMethodBuilder.url.handle_model_call(self, @product_page)

    assert_equal "http://www.example.com/manufacturers/apple", polymorphic_url(@manufacturer)
    assert_equal "http://www.example.com/manufacturers/apple", Routes.url_helpers.polymorphic_url(@manufacturer)
  end

  def test_defining_direct_inside_a_scope_raises_runtime_error
    routes = ActionDispatch::Routing::RouteSet.new

    assert_raises RuntimeError do
      routes.draw do
        namespace :admin do
          direct(:rubyonrails) { "http://www.rubyonrails.org" }
        end
      end
    end
  end

  def test_defining_resolve_inside_a_scope_raises_runtime_error
    routes = ActionDispatch::Routing::RouteSet.new

    assert_raises RuntimeError do
      routes.draw do
        namespace :admin do
          resolve("User") { "/profile" }
        end
      end
    end
  end

  def test_defining_direct_url_registers_helper_method
    assert_equal "http://www.example.com/basket", Routes.url_helpers.symbol_url
    assert_equal true, Routes.named_routes.route_defined?(:symbol_url), "'symbol_url' named helper not found"
    assert_equal true, Routes.named_routes.route_defined?(:symbol_path), "'symbol_path' named helper not found"
  end
end
