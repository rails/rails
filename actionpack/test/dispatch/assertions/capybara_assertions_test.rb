# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/testing/assertions/capybara"

class CapybaraAssertionsTest < ActionDispatch::IntegrationTest
  include ActionDispatch::Assertions::CapybaraAssertions

  ROUTES = ActionDispatch::Routing::RouteSet.new
  ROUTES.draw do
    post "/", to: "capybara_assertions_test/renders#create"
  end

  APP = build_app(ROUTES)

  def app
    APP
  end

  class RendersController < ActionController::Base
    def create
      render inline: params[:template]
    end
  end

  test "assert scoped within an element" do
    post "/", params: { template: <<~HTML }
      <header><h1>Header</h1></header>
      <main><h1>Main</h1></main>
    HTML

    assert_selector "header h1", text: "Header"
    assert_selector "main h1", text: "Main"

    within "header" do
      assert_selector "h1", text: "Header"
      assert_no_selector "h1", text: "Main"
    end

    within "main" do
      assert_no_selector "h1", text: "Header"
      assert_selector "h1", text: "Main"
    end
  end

  test "assert_select with Capybara instead of rails-dom-testing" do
    post "/", params: { template: <<~HTML }
      <label for="name">Name</label>
      <select id="name"><option>First</option></select>
    HTML

    assert_select "Name", options: ["First"]
  end
end
