# encoding: utf-8
require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class MiddlewareSessionTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "config.force_ssl sets cookie to secure only" do
      add_to_config "config.force_ssl = true"
      require "#{app_path}/config/environment"
      assert app.config.session_options[:secure], "Expected session to be marked as secure"
    end

    test "session is not loaded if it's not used" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          if params[:flash]
            flash[:notice] = "notice"
          end

          render :nothing => true
        end
      end

      get "/?flash=true"
      get "/"

      assert last_request.env["HTTP_COOKIE"]
      assert !last_response.headers["Set-Cookie"]
    end
  end
end
