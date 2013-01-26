require "isolation/abstract_unit"
require "railties/shared_tests"

module RailtiesTest
  class PluginTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include SharedTests

    def setup
      build_app

      @plugin = plugin "bukkits", "::LEVEL = config.log_level" do |plugin|
        plugin.write "lib/bukkits.rb", "class Bukkits; end"
        plugin.write "lib/another.rb", "class Another; end"
      end
    end

    def teardown
      teardown_app
    end

    test "Rails::Plugin itself does not respond to config" do
      boot_rails
      assert !Rails::Plugin.respond_to?(:config)
    end

    test "cannot inherit from Rails::Plugin" do
      boot_rails
      assert_raise RuntimeError do
        class Foo < Rails::Plugin; end
      end
    end

    test "plugin can load the file with the same name in lib" do
      boot_rails
      require "bukkits"
      assert_equal "Bukkits", Bukkits.name
    end

    test "plugin gets added to dependency list" do
      boot_rails
      assert_equal "Another", Another.name
    end

    test "plugin constants get reloaded if config.reload_plugins is set to true" do
      add_to_config <<-RUBY
        config.reload_plugins = true
      RUBY

      boot_rails

      assert_equal "Another", Another.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/another.rb")
      assert_raises(NameError) { Another }
    end

    test "plugin constants are not reloaded by default" do
      boot_rails
      assert_equal "Another", Another.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/another.rb")
      assert_nothing_raised { Another }
    end

    test "it loads the plugin's init.rb file" do
      boot_rails
      assert_equal "loaded", BUKKITS
    end

    test "the init.rb file has access to the config object" do
      boot_rails
      assert_equal :debug, LEVEL
    end

    test "plugin_init_is_run_before_application_ones" do
      plugin "foo", "$foo = true" do |plugin|
        plugin.write "lib/foo.rb", "module Foo; end"
      end

      app_file 'config/initializers/foo.rb', <<-RUBY
        raise "no $foo" unless $foo
        raise "no Foo" unless Foo
      RUBY

      boot_rails
      assert $foo
    end

    test "plugin should work without init.rb" do
      @plugin.delete("init.rb")

      boot_rails

      require "bukkits"
      assert_nothing_raised { Bukkits }
    end

    test "plugin cannot declare an engine for it" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < Rails::Engine
          end
        end
      RUBY

      @plugin.write "init.rb", <<-RUBY
        require "bukkits"
      RUBY

      rescued = false

      begin
        boot_rails
      rescue Exception => e
        rescued = true
        assert_equal '"bukkits" is a Railtie/Engine and cannot be installed as a plugin', e.message
      end

      assert rescued, "Expected boot rails to fail"
    end

    test "loads deprecated rails/init.rb" do
      @plugin.write "rails/init.rb", <<-RUBY
        $loaded = true
      RUBY

      boot_rails
      assert $loaded
    end

    test "deprecated tasks are also loaded" do
      $executed = false
      @plugin.write "tasks/foo.rake", <<-RUBY
        task :foo do
          $executed = true
        end
      RUBY

      boot_rails
      require 'rake'
      require 'rake/testtask'
      Rails.application.load_tasks
      Rake::Task[:foo].invoke
      assert $executed
    end
  end
end
