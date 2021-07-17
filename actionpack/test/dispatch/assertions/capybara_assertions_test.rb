# frozen_string_literal: true

require "abstract_unit"

class CapybaraAssertionsTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Benchmarkable

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    scope module: "capybara_assertions_test" do
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

  assert_with :capybara

  test "assert scoped within an element" do
    get "/"

    assert_selector "h1", text: "Header"
    within "main" do
      assert_selector "h1", text: "Posts"
      assert_no_selector "h1", text: "Header"
    end
  end

  test "assert a <select> element" do
    get "/"

    assert_select "Name", options: ["First"]
  end
end
