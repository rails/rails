# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class HooksTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    test "load initializers" do
      app_file "config/initializers/foo.rb", "$foo = true"
      require "#{app_path}/config/environment"
      assert $foo
    end

    test "hooks block works correctly without eager_load (before_eager_load is not called)" do
      add_to_config <<-RUBY
        $initialization_callbacks = []
        config.root = "#{app_path}"
        config.eager_load = false
        config.before_configuration { $initialization_callbacks << 1 }
        config.before_initialize    { $initialization_callbacks << 2 }
        config.before_eager_load    { Boom }
        config.after_initialize     { $initialization_callbacks << 3 }
      RUBY

      require "#{app_path}/config/environment"
      assert_equal [1, 2, 3], $initialization_callbacks
    end

    test "hooks block works correctly with eager_load" do
      add_to_config <<-RUBY
        $initialization_callbacks = []
        config.root = "#{app_path}"
        config.eager_load = true
        config.before_configuration { $initialization_callbacks << 1 }
        config.before_initialize    { $initialization_callbacks << 2 }
        config.before_eager_load    { $initialization_callbacks << 3 }
        config.after_initialize     { $initialization_callbacks << 4 }
      RUBY

      require "#{app_path}/config/environment"
      assert_equal [1, 2, 3, 4], $initialization_callbacks
    end

    test "after_initialize runs after frameworks have been initialized" do
      $activerecord_configurations = nil
      add_to_config <<-RUBY
        config.after_initialize { $activerecord_configurations = ActiveRecord::Base.configurations }
      RUBY

      require "#{app_path}/config/environment"
      assert $activerecord_configurations
      assert $activerecord_configurations["development"]
    end

    test "after_initialize happens after to_prepare in development" do
      $order = []
      add_to_config <<-RUBY
        config.cache_classes = false
        config.after_initialize { $order << :after_initialize }
        config.to_prepare { $order << :to_prepare }
      RUBY

      require "#{app_path}/config/environment"
      assert_equal [:to_prepare, :after_initialize], $order
    end

    test "after_initialize happens after to_prepare in production" do
      $order = []
      add_to_config <<-RUBY
        config.cache_classes = true
        config.after_initialize { $order << :after_initialize }
        config.to_prepare { $order << :to_prepare }
      RUBY

      require "#{app_path}/config/application"
      Rails.env.replace "production"
      require "#{app_path}/config/environment"
      assert_equal [:to_prepare, :after_initialize], $order
    end
  end
end
