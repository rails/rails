# -*- coding: utf-8 -*-
require 'isolation/abstract_unit'
require 'rack/test'
require 'rails'
require 'action_controller/railtie'

module ApplicationTests
  class MultipleApplicationsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    class NewApplication < Rails::Application
    end

    class AnotherApplication < Rails::Application
    end

    def setup
      build_app(initializers: true)
      app
    end

    def teardown
      teardown_app
    end

    def test_cloning_an_application_makes_a_shallow_copy
      clone = Rails.application.clone

      assert_equal Rails.application.config, clone.config
      assert_equal Rails.application.reloaders, clone.reloaders
      assert_equal Rails.application.routes_reloader, clone.routes_reloader
      assert_equal Rails.application.railties, clone.railties
      assert_equal Rails.application.routes, clone.routes
      assert_equal Rails.application.helpers, clone.helpers
      assert_equal Rails.application.env_config, clone.env_config

      Rails.application.config.secret_key_base = "555555555"
      assert_equal Rails.application.config, clone.config
    end

    def test_initialization_of_multiple_copies_of_same_application
      application1 = AppTemplate::Application.new
      application2 = NewApplication.new

      assert_not_equal Rails.application, application1, "New applications should not be the same as the original application"
      assert_not_equal Rails.application, application2, "New applications should not be the same as the original application"
    end

     def test_multiple_applications_can_be_initialized
      assert_nothing_raised { NewApplication.new }
      assert_nothing_raised { NewApplication.new }
      assert_nothing_raised { AnotherApplication.new }
    end

    def test_multiple_applications_all_have_the_same_global_config
      application1 = NewApplication.new
      application2 = AnotherApplication.new

      assert_equal Rails.config, Rails.application.config, "The Rails.application configuration should be the same as the global rails configuration"
      assert_equal Rails.config, application1.config, "All applications should have the same global config"
      assert_equal Rails.config, application2.config, "All applications should have the same global config"

      new_secret_key = "123456789"
      Rails.config.secret_key_base = new_secret_key

      assert_equal new_secret_key, Rails.config.secret_key_base, "We should have a new secret_key_base in the configuration"
      assert_equal Rails.config.secret_key_base, Rails.application.config.secret_key_base, "Changing the global config should change the configs on all applications"
      assert_equal Rails.config.secret_key_base, application1.config.secret_key_base, "Changing the global config should change the configs on all applications"
      assert_equal Rails.config.secret_key_base, application2.config.secret_key_base, "Changing the global config should change the configs on all applications"
    end

    def test_configuring_Rails_application_will_correctly_change_the_config
      new_secret_key = "123456789"
      Rails::Application.configure do
        config.secret_key_base = new_secret_key
      end

      assert_equal new_secret_key, Rails.config.secret_key_base, "Using configure on class should change the global configuration"
      assert_equal new_secret_key, Rails.application.config.secret_key_base, "Using configure on class should change the global configuration"

      new_secret_key = "987654321"
      Rails.configure do |config|
        config.secret_key_base = new_secret_key
      end

      assert_equal new_secret_key, Rails.config.secret_key_base, "Using Rails.configure should change the global configuration"
      assert_equal new_secret_key, Rails.application.config.secret_key_base, "Using Rails.configure should change the global configuration"
    end
  end
end
