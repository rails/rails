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

    test "a deprecation is generated when a user reference the Flash Middleware" do
      add_to_env_config("development", "config.active_support.deprecation = :raise")

      add_to_config <<-CONFIG
        config.middleware.swap ActionDispatch::Flash, Rack::Head
      CONFIG

      error = assert_raises(ActiveSupport::DeprecationException) do
        require "#{app_path}/config/environment"
      end

      assert_match("The ActionDispatch::Flash middleware is deprecated", error.message)
    end

    test "no deprecation is generated when the Flash middleware is not referenced" do
      add_to_env_config("development", "config.active_support.deprecation = :raise")

      assert_nothing_raised do
        require "#{app_path}/config/environment"
      end
    end
  end
end
