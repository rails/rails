# frozen_string_literal: true

require "abstract_unit"

class RailsDomTestingAssertionsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Benchmarkable

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "rails_dom_testing_assertions_test" do
      get "/", to: "posts#index"
    end
  end

  APP = build_app(ROUTES)

  def app
    APP
  end

  class PostsController < ActionController::Base
    def index
      render inline: <<~HTML
        <header>
          <h1>Header</h1>
        </header>
        <main>
          <h1>Posts</h1>
          <label for="name">Name</label>
          <select id="name">
            <option>First</option>
          </select>
        </main>
      HTML
    end
  end

  assert_with :rails_dom_testing

  test "assert scoped within an element" do
    get "/"

    assert_select "h1", text: "Header"
    assert_select "main" do
      assert_select "h1", text: "Posts"
      assert_select "h1", text: "Header", count: 0
    end
  end

  test "assert a <select> element" do
    get "/"

    assert_select "select" do
      assert_select "option", text: "First"
    end
  end
end
