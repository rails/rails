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
    match "/redirect/*path", via: [:get], to: redirect(path: "/works/%{path}", only_path: true)

    namespace :works, path: "works" do
      resources :users, only: [:index]
    end
  end

  test "redirection" do
    get "/redirect/users"
    assert_response :redirect
    assert_equal "/works/users", response.headers["Location"]
  end
end
