require "isolation/abstract_unit"

module ApplicationTests
  class InitializersTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    test "load initializers" do
      app_file "config/initializers/foo.rb", "$foo = true"
      require "#{app_path}/config/environment"
      assert $foo
    end

    test "after_initialize block works correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      RUBY
      require "#{app_path}/config/environment"

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    test "after_initialize block works correctly when no block is passed" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize # don't pass a block, this is what we're testing!
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      RUBY
      require "#{app_path}/config/environment"

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    test "after_initialize runs after frameworks have been initialized" do
      $activerecord_configurations = nil
      add_to_config <<-RUBY
        config.after_initialize { $activerecord_configurations = ActiveRecord::Base.configurations }
      RUBY

      require "#{app_path}/config/environment"
      assert $activerecord_configurations
      assert $activerecord_configurations['development']
    end

    test "after_initialize happens after to_prepare in development" do
      $order = []
      add_to_config <<-RUBY
        config.cache_classes = false
        config.after_initialize { $order << :after_initialize }
        config.to_prepare { $order << :to_prepare }
      RUBY

      require "#{app_path}/config/environment"
      assert [:to_prepare, :after_initialize], $order
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
      assert [:to_prepare, :after_initialize], $order
    end
  end
end
