require "isolation/abstract_unit"

module ApplicationTests
  class LoadPathTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    test "initializing an application adds the application paths to the load path" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      assert $:.include?("#{app_path}/app/models")
    end

    test "initializing an application allows to load code on lib path inside application class definitation" do
      app_file "lib/foo.rb", <<-RUBY
        module Foo; end
      RUBY

      add_to_config <<-RUBY
        require "foo"
        raise "Expected Foo to be defined" unless defined?(Foo)
      RUBY

      assert_nothing_raised do
        require "#{app_path}/config/environment"
      end

      assert $:.include?("#{app_path}/lib")
    end

    test "initializing an application eager load any path under app" do
      app_file "app/anything/foo.rb", <<-RUBY
        module Foo; end
      RUBY

      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      assert Foo
    end

    test "eager loading loads parent classes before children" do
      app_file "lib/zoo.rb", <<-ZOO
        class Zoo ; include ReptileHouse ; end
      ZOO

      app_file "lib/zoo/reptile_house.rb", <<-ZOO
        module Zoo::ReptileHouse ; end
      ZOO

      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.eager_load_paths << "#{app_path}/lib"
      RUBY

      require "#{app_path}/config/environment"
      assert Zoo
    end

    test "load environment with global" do
      app_file "config/environments/development.rb", <<-RUBY
        $initialize_test_set_from_env = 'success'
        AppTemplate::Application.configure do
          config.cache_classes = true
          config.time_zone = "Brasilia"
        end
      RUBY

      assert_nil $initialize_test_set_from_env
      add_to_config <<-RUBY
        config.root = "#{app_path}"
          config.time_zone = "UTC"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "success", $initialize_test_set_from_env
      assert AppTemplate::Application.config.cache_classes
      assert_equal "Brasilia", AppTemplate::Application.config.time_zone
    end
  end
end
