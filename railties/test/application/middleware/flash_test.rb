# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class FlashTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    test "a deprecation is generated when an application reference the Flash Middleware" do
      add_to_env_config("development", "config.active_support.deprecation = :raise")

      add_to_config <<-CONFIG
        config.middleware.swap ActionDispatch::Flash, Rack::Head
      CONFIG

      error = assert_raises(ActiveSupport::DeprecationException) do
        require "#{app_path}/config/environment"
      end

      assert_match(<<~EOM, error.message)
        The ActionDispatch::Flash middleware is deprecated without
        replacement and will be deleted in the next version of Rails.

        If you used the ActionDispatch::Flash constant in your
        application for inserting other middlewares, in example:
        config.middleware.insert_after(ActionDispatch::Flash, MyMiddleware))
        this will no longer work.

        The Flash feature still exists and will work exactly the
        same way as before, only the middleware will be removed.
      EOM
    end

    test "a deprecation is generated when an application use the Flash Middleware" do
      add_to_env_config("development", "config.active_support.deprecation = :raise")

      add_to_config <<-CONFIG
        config.api_only = true
        config.middleware.use ActionDispatch::Flash
      CONFIG

      error = assert_raises(ActiveSupport::DeprecationException) do
        require "#{app_path}/config/environment"
      end

      assert_match(<<~EOM, error.message)
        The ActionDispatch::Flash middleware is deprecated without
        replacement and will be deleted in the next version of Rails.

        To enable the flash feature in your application, call
        `ActionDispatch::Request::Flash.use!` during the boot process
        (e.g. inside a Rails initializer).
      EOM
    end

    test "no deprecation is generated when the Flash middleware is not referenced" do
      add_to_env_config("development", "config.active_support.deprecation = :raise")

      assert_nothing_raised do
        require "#{app_path}/config/environment"
      end
    end
  end
end
