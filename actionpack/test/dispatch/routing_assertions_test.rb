# frozen_string_literal: true

require "abstract_unit"
require "rails/engine"
require "controller/fake_controllers"

class SecureArticlesController < ArticlesController
  def index
    render(inline: "")
  end
end
class BlockArticlesController < ArticlesController; end
class QueryArticlesController < ArticlesController; end

class SecureBooksController < BooksController; end
class BlockBooksController < BooksController; end
class QueryBooksController < BooksController; end

module RoutingAssertionsSharedTests
  def setup
    root_engine = Class.new(Rails::Engine) do
      def self.name
        "root_engine"
      end
    end

    root_engine.routes.draw do
      root to: "books#index"
    end

    engine = Class.new(Rails::Engine) do
      def self.name
        "blog_engine"
      end
    end

    engine.routes.draw do
      resources :books

      scope "secure", constraints: { protocol: "https://" } do
        resources :books, controller: "secure_books"
      end

      scope "block", constraints: lambda { |r| r.ssl? } do
        resources :books, controller: "block_books"
      end

      scope "query", constraints: lambda { |r| r.params[:use_query] == "true" } do
        resources :books, controller: "query_books"
      end
    end

    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      resources :articles

      scope "secure", constraints: { protocol: "https://" } do
        resources :articles, controller: "secure_articles"
      end

      scope "block", constraints: lambda { |r| r.ssl? } do
        resources :articles, controller: "block_articles"
      end

      scope "query", constraints: lambda { |r| r.params[:use_query] == "true" } do
        resources :articles, controller: "query_articles"
      end

      mount engine => "/shelf"

      mount root_engine => "/"

      get "/shelf/foo", controller: "query_articles", action: "index"
    end
  end

  def test_assert_generates
    assert_generates("/articles", controller: "articles", action: "index")
    assert_generates("/articles/1", controller: "articles", action: "show", id: "1")
  end

  def test_assert_generates_with_defaults
    assert_generates("/articles/1/edit", { controller: "articles", action: "edit" }, { id: "1" })
  end

  def test_assert_generates_with_extras
    assert_generates("/articles", { controller: "articles", action: "index", page: "1" }, {}, { page: "1" })
  end

  def test_assert_recognizes
    assert_recognizes({ controller: "articles", action: "index" }, "/articles")
    assert_recognizes({ controller: "articles", action: "show", id: "1" }, "/articles/1")
  end

  def test_assert_recognizes_with_extras
    assert_recognizes({ controller: "articles", action: "index", page: "1" }, "/articles", page: "1")
  end

  def test_assert_recognizes_with_method
    assert_recognizes({ controller: "articles", action: "create" }, { path: "/articles", method: :post })
    assert_recognizes({ controller: "articles", action: "update", id: "1" }, { path: "/articles/1", method: :put })
  end

  def test_assert_recognizes_with_hash_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "secure_articles", action: "index" }, "http://test.host/secure/articles")
    end
    assert_recognizes({ controller: "secure_articles", action: "index", protocol: "https://" }, "https://test.host/secure/articles")
  end

  def test_assert_recognizes_with_block_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "block_articles", action: "index" }, "http://test.host/block/articles")
    end
    assert_recognizes({ controller: "block_articles", action: "index" }, "https://test.host/block/articles")
  end

  def test_assert_recognizes_with_query_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "query_articles", action: "index", use_query: "false" }, "/query/articles", use_query: "false")
    end
    assert_recognizes({ controller: "query_articles", action: "index", use_query: "true" }, "/query/articles", use_query: "true")
  end

  def test_assert_recognizes_raises_message
    err = assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "secure_articles", action: "index" }, "http://test.host/secure/articles", {}, "This is a really bad msg")
    end

    assert_match err.message, "This is a really bad msg"
  end

  def test_assert_recognizes_with_engine
    assert_recognizes({ controller: "books", action: "index" }, "/shelf/books")
    assert_recognizes({ controller: "books", action: "show", id: "1" }, "/shelf/books/1")
  end

  def test_assert_recognizes_with_engine_at_root
    assert_recognizes({ controller: "books", action: "index" }, "/")
  end

  def test_assert_recognizes_with_engine_and_extras
    assert_recognizes({ controller: "books", action: "index", page: "1" }, "/shelf/books", page: "1")
  end

  def test_assert_recognizes_with_engine_and_method
    assert_recognizes({ controller: "books", action: "create" }, { path: "/shelf/books", method: :post })
    assert_recognizes({ controller: "books", action: "update", id: "1" }, { path: "/shelf/books/1", method: :put })
  end

  def test_assert_recognizes_with_engine_and_hash_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "secure_books", action: "index" }, "http://test.host/shelf/secure/books")
    end
    assert_recognizes({ controller: "secure_books", action: "index", protocol: "https://" }, "https://test.host/shelf/secure/books")
  end

  def test_assert_recognizes_with_engine_and_block_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "block_books", action: "index" }, "http://test.host/shelf/block/books")
    end
    assert_recognizes({ controller: "block_books", action: "index" }, "https://test.host/shelf/block/books")
  end

  def test_assert_recognizes_with_engine_and_query_constraint
    assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "query_books", action: "index", use_query: "false" }, "/shelf/query/books", use_query: "false")
    end
    assert_recognizes({ controller: "query_books", action: "index", use_query: "true" }, "/shelf/query/books", use_query: "true")
  end

  def test_assert_recognizes_raises_message_with_engine
    err = assert_raise(Minitest::Assertion) do
      assert_recognizes({ controller: "secure_books", action: "index" }, "http://test.host/shelf/secure/books", {}, "This is a really bad msg")
    end

    assert_match err.message, "This is a really bad msg"
  end

  def test_assert_recognizes_continue_to_recognize_after_it_tried_engines
    assert_recognizes({ controller: "query_articles", action: "index" }, "/shelf/foo")
  end

  def test_assert_routing
    assert_routing("/articles", controller: "articles", action: "index")
  end

  def test_assert_routing_raises_message
    err = assert_raise(Minitest::Assertion) do
      assert_routing("/thisIsNotARoute", { controller: "articles", action: "edit", id: "1" }, { id: "1" }, {}, "This is a really bad msg")
    end

    assert_match err.message, "This is a really bad msg"
  end

  def test_assert_routing_with_defaults
    assert_routing("/articles/1/edit", { controller: "articles", action: "edit", id: "1" }, { id: "1" })
  end

  def test_assert_routing_with_extras
    assert_routing("/articles", { controller: "articles", action: "index", page: "1" }, {}, { page: "1" })
  end

  def test_assert_routing_with_hash_constraint
    assert_raise(Minitest::Assertion) do
      assert_routing("http://test.host/secure/articles", controller: "secure_articles", action: "index")
    end
    assert_routing("https://test.host/secure/articles", controller: "secure_articles", action: "index", protocol: "https://")
  end

  def test_assert_routing_with_block_constraint
    assert_raise(Minitest::Assertion) do
      assert_routing("http://test.host/block/articles", controller: "block_articles", action: "index")
    end
    assert_routing("https://test.host/block/articles", controller: "block_articles", action: "index")
  end

  def test_with_routing
    with_routing do |routes|
      routes.draw do
        resources :articles, path: "artikel"
      end

      assert_routing("/artikel", controller: "articles", action: "index")
      assert_raise(Minitest::Assertion) do
        assert_routing("/articles", controller: "articles", action: "index")
      end
    end
  end

  module WithRoutingSharedTests
    extend ActiveSupport::Concern

    def before_setup
      @routes = ActionDispatch::Routing::RouteSet.new
      @routes.draw do
        resources :articles
      end

      super
    end

    included do
      with_routing do |routes|
        routes.draw do
          resources :articles, path: "artikel"
        end
      end
    end

    def test_with_routing_for_the_entire_test_file
      assert_routing("/artikel", controller: "articles", action: "index")
      assert_raise(Minitest::Assertion) do
        assert_routing("/articles", controller: "articles", action: "index")
      end
    end

    def test_with_routing_for_entire_test_file_can_be_overwritten_for_individual_test
      with_routing do |routes|
        routes.draw do
          resources :articles, path: "articolo"
        end

        assert_routing("/articolo", controller: "articles", action: "index")
        assert_raise(Minitest::Assertion) do
          assert_routing("/artikel", controller: "articles", action: "index")
        end
      end

      assert_routing("/artikel", controller: "articles", action: "index")
      assert_raise(Minitest::Assertion) do
        assert_routing("/articolo", controller: "articles", action: "index")
      end
    end
  end
end

class RoutingAssertionsControllerTest < ActionController::TestCase
  include RoutingAssertionsSharedTests

  class WithRoutingTest < ActionController::TestCase
    include RoutingAssertionsSharedTests::WithRoutingSharedTests

    test "with_routing routes are reachable" do
      @controller = SecureArticlesController.new

      with_routing do |routes|
        routes.draw do
          get :new_route, to: "secure_articles#index"
        end

        get :index

        assert_predicate(response, :ok?)
      end
    end
  end
end

class RoutingAssertionsIntegrationTest < ActionDispatch::IntegrationTest
  include RoutingAssertionsSharedTests

  test "https and host settings are set on new session" do
    https!
    host! "newhost.com"

    with_routing do |routes|
      routes.draw {  }
      assert_predicate integration_session, :https?
      assert_equal "newhost.com", integration_session.host
    end
  end

  class WithRoutingTest < ActionDispatch::IntegrationTest
    include RoutingAssertionsSharedTests::WithRoutingSharedTests

    test "with_routing routes are reachable" do
      with_routing do |routes|
        routes.draw do
          get :new_route, to: "secure_articles#index"
        end

        get "/new_route"

        assert_predicate(response, :ok?)
      end
    end
  end

  class WithRoutingSettingsTest < ActionDispatch::IntegrationTest
    setup do
      https!
      host! "newhost.com"
    end

    with_routing do |routes|
      routes.draw {  }
    end

    test "https and host settings are set on new session" do
      assert_predicate integration_session, :https?
      assert_equal "newhost.com", integration_session.host
    end
  end
end
