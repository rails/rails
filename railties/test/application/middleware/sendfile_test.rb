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

    test "config.action_dispatch.x_sendfile_header cannot be set" do
      make_basic_app do |app|
        msg = /`config.action_dispatch.x_sendfile_header` is deprecated/
        assert_deprecated(msg, ActionDispatch.deprecator) do
          app.config.action_dispatch.x_sendfile_header = "X-Sendfile"
        end

        assert_nil app.config.action_dispatch.x_sendfile_header
      end

      simple_controller

      get "/"
      assert_not last_response.headers["X-Sendfile"]
      assert_equal File.read(__FILE__), last_response.body
    end
  end
end
