# frozen_string_literal: true

require "bundler/inline"


require "rack/test"
require "action_controller/railtie"
require "minitest/autorun"
require "action_dispatch/journey"

class BugTest < ActiveSupport::TestCase
  attr_accessor :controller, :request

  routes = ActionDispatch::Routing::RouteSet.new
  routes.draw do
    root "posts#index"
    resources :posts, only: :index
  end

  include ActionView::Helpers::UrlHelper
  include routes.url_helpers

  def request_for_url(url, opts = {})
    env = Rack::MockRequest.env_for("http://www.example.com#{url}", opts)
    ActionDispatch::Request.new(env)
  end

  def test_returns_success
    @request = request_for_url("/posts", method: :head)
    assert current_page?(controller: "posts", action: "index")
  end
end
