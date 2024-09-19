# frozen_string_literal: true

require "abstract_unit"

class ToolsControllerTest < ActionController::TestCase
  include ActiveSupport::Testing::Isolation
  tests Rails::ToolsController

  def setup
    ActionController::Base.include ActionController::Testing

    Rails.application.routes.draw do
      get "/rails" => "rails/tools#index"
    end
    @routes = Rails.application.routes

    @request.env["REMOTE_ADDR"] = "127.0.0.1"
  end

  test "tools controller does not allow remote requests" do
    @request.env["REMOTE_ADDR"] = "example.org"
    get :index
    assert_response :forbidden
  end

  test "tools controller renders an error message when request was forbidden" do
    @request.env["REMOTE_ADDR"] = "example.org"
    get :index
    assert_select "p"
  end

  test "tools controller allows requests when all requests are considered local" do
    @request.env["REMOTE_ADDR"] = "example.org"
    Rails.application.config.consider_all_requests_local = true
    get :index
    assert_response :success
  ensure
    Rails.application.config.consider_all_requests_local = false
  end

  test "tools controller allows local requests" do
    get :index
    assert_response :success
  end

  test "tools controller renders a list of tools" do
    get :index

    assert_select("h3", text: "Info")
    assert_select("ul li", text: "Routes")
    assert_select("ul li", text: "Notes")
    assert_select("ul li", text: "Properties")

    assert_select("h3", text: "Mailers")
    assert_select("ul li", text: "Preview")
  end
end
