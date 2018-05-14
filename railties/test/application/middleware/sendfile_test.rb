# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class SendfileTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    define_method :simple_controller do
      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end
    end

    # x_sendfile_header middleware
    test "config.action_dispatch.x_sendfile_header defaults to nil" do
      make_basic_app
      simple_controller

      get "/"
      assert_not last_response.headers["X-Sendfile"]
      assert_equal File.read(__FILE__), last_response.body
    end

    test "config.action_dispatch.x_sendfile_header can be set" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = "X-Sendfile"
      end

      simple_controller

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Sendfile"]
    end

    test "config.action_dispatch.x_sendfile_header is sent to Rack::Sendfile" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = "X-Lighttpd-Send-File"
      end

      simple_controller

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Lighttpd-Send-File"]
    end

    test "files handled by ActionDispatch::Static are handled by Rack::Sendfile" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = "X-Sendfile"
        app.config.public_file_server.enabled = true
        app.paths["public"] = File.join(rails_root, "public")
      end

      app_file "public/foo.txt", "foo"

      get "/foo.txt", "HTTP_X_SENDFILE_TYPE" => "X-Sendfile"
      assert_equal File.join(rails_root, "public/foo.txt"), last_response.headers["X-Sendfile"]
    end
  end
end
