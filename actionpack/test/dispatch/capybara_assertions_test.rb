# frozen_string_literal: true

require "abstract_unit"

class RendersController < ActionController::Base
  def create
    render inline: params[:template]
  end
end

class ControllerCapybaraAssertionsTest < ActionController::TestCase
  include ActionView::CapybaraAssertions

  setup do
    @controller = RendersController.new
  end

  test "assert with Capybara selectors" do
    post :create, params: { template: <<~HTML }
      <html>
        <head>
          <title>Hello, world</title>
        </head>
        <body>
          <header>Header</header>
          <main>Main</main>
        </body>
      </html>
    HTML

    assert_title "Hello, world"
    assert_selector "header", text: "Header"
    assert_selector "main", text: "Main"
  end

  test "assert scoped within an element" do
    post :create, params: { template: <<~HTML }
      <header><h1>Header</h1></header>
      <main><h1>Main</h1></main>
    HTML

    assert_selector "header" do |header|
      assert_selector header, "h1", text: "Header"
      assert_no_selector header, "h1", text: "Main"
    end

    assert_selector "main" do |main|
      assert_no_selector main, "h1", text: "Header"
      assert_selector main, "h1", text: "Main"
    end
  end

  test "assert_select with Capybara instead of rails-dom-testing" do
    post :create, params: { template: <<~HTML }
      <label for="name">Name</label>
      <select id="name"><option>First</option></select>
    HTML

    assert_select "Name", options: ["First"]
  end

  test "page isn't shared across requests" do
    post :create, params: { template: <<~HTML }
      <h1>First</h1>
    HTML

    assert_selector "h1", text: "First"

    post :create, params: { template: <<~HTML }
      <h1>Second</h1>
    HTML

    assert_selector "h1", text: "Second"
  end
end

class IntegrationCapybaraAssertionsTest < ActionDispatch::IntegrationTest
  include ActionView::CapybaraAssertions

  APP = build_app(ActionDispatch::Routing::RouteSet.new.tap { |routes|
    routes.draw { post "/", to: "renders#create" }
  })

  def app
    APP
  end

  test "assert with Capybara selectors" do
    post "/", params: { template: <<~HTML }
      <html>
        <head>
          <title>Hello, world</title>
        </head>
        <body>
          <header>Header</header>
          <main>Main</main>
        </body>
      </html>
    HTML

    assert_title "Hello, world"
    assert_selector "header", text: "Header"
    assert_selector "main", text: "Main"
  end


  test "assert scoped within an element" do
    post "/", params: { template: <<~HTML }
      <header><h1>Header</h1></header>
      <main><h1>Main</h1></main>
    HTML

    assert_selector "header" do |header|
      assert_selector header, "h1", text: "Header"
      assert_no_selector header, "h1", text: "Main"
    end

    assert_selector "main" do |main|
      assert_no_selector main, "h1", text: "Header"
      assert_selector main, "h1", text: "Main"
    end
  end

  test "assert_select with Capybara instead of rails-dom-testing" do
    post "/", params: { template: <<~HTML }
      <label for="name">Name</label>
      <select id="name"><option>First</option></select>
    HTML

    assert_select "Name", options: ["First"]
  end

  test "page isn't shared across requests" do
    post "/", params: { template: <<~HTML }
      <h1>First</h1>
    HTML

    assert_selector "h1", text: "First"

    post "/", params: { template: <<~HTML }
      <h1>Second</h1>
    HTML

    assert_selector "h1", text: "Second"
  end
end
