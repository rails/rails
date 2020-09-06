# frozen_string_literal: true

require 'abstract_unit'

class IPv6IntegrationTest < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new
  include Routes.url_helpers

  class ::BadRouteRequestController < ActionController::Base
    include Routes.url_helpers
    def index
      render plain: foo_path
    end

    def foo
      redirect_to action: :index
    end
  end

  Routes.draw do
    get '/',    to: 'bad_route_request#index', as: :index
    get '/foo', to: 'bad_route_request#foo', as: :foo
  end

  def _routes
    Routes
  end

  APP = build_app Routes
  def app
    APP
  end

  test 'bad IPv6 redirection' do
    #   def test_simple_redirect
    request_env = {
      'REMOTE_ADDR' => 'fd07:2fa:6cff:2112:225:90ff:fec7:22aa',
      'HTTP_HOST'   => '[fd07:2fa:6cff:2112:225:90ff:fec7:22aa]:3000',
      'SERVER_NAME' => '[fd07:2fa:6cff:2112:225:90ff:fec7:22aa]',
      'SERVER_PORT' => 3000 }

    get '/foo', env: request_env
    assert_response :redirect
    assert_equal 'http://[fd07:2fa:6cff:2112:225:90ff:fec7:22aa]:3000/', redirect_to_url
  end
end
