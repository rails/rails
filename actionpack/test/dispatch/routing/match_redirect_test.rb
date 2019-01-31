# frozen_string_literal: true

require "abstract_unit"

class MatchRedirectIntegrationTest < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new
  APP = build_app Routes

  include Routes.url_helpers

  def _routes
    Routes
  end

  def app
    APP
  end

  module Works
    class UsersController < ActionController::Base
      include Routes.url_helpers
      def index
        render plain: foo_path
      end
    end
  end

  Routes.draw do
    match "/option_redirect_full_uri/*path", via: [:get], to: redirect(path: "/works/%{path}")
    match "/option_redirect_path_only/*path", via: [:get], to: redirect(path: "/works/%{path}", only_path: true)
    match "/path_redirect/*path", via: [:get], to: redirect("/works/%{path}")

    namespace :works, path: "works" do
      resources :users, only: [:index]
    end
  end

  test "OptionRedirect full URI redirection" do
    get "/option_redirect_full_uri/users"
    assert_response :redirect
    assert_equal "http://www.example.com/works/users", response.headers["Location"]
  end

  test "OptionRedirect path only redirection" do
    get "/option_redirect_path_only/users"
    assert_response :redirect
    assert_equal "/works/users", response.headers["Location"]
  end
end
