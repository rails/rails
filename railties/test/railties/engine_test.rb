require "isolation/abstract_unit"
require "railties/shared_tests"

module RailtiesTest
  class EngineTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include SharedTests

    def setup
      build_app

      @plugin = engine "bukkits" do |plugin|
        plugin.write "lib/bukkits.rb", <<-RUBY
          class Bukkits
            class Engine < ::Rails::Engine
            end
          end
        RUBY
        plugin.write "lib/another.rb", "class Another; end"
      end
    end

    test "Rails::Engine itself does not respond to config" do
      boot_rails
      assert !Rails::Engine.respond_to?(:config)
    end

    test "initializers are executed after application configuration initializers" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            initializer "dummy_initializer" do
            end
          end
        end
      RUBY

      boot_rails

      initializers = Rails.application.initializers.tsort
      index        = initializers.index { |i| i.name == "dummy_initializer" }
      selection    = initializers[(index-3)..(index)].map(&:name).map(&:to_s)

      assert_equal %w(
       load_config_initializers
       load_config_initializers
       engines_blank_point
       dummy_initializer
      ), selection

      assert index < initializers.index { |i| i.name == :build_middleware_stack }
    end

    class Upcaser
      def initialize(app)
        @app = app
      end

      def call(env)
        response = @app.call(env)
        response[2].upcase!
        response
      end
    end

    test "engine is a rack app and can have his own middleware stack" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, 'Hello World'] }

            config.middleware.use ::RailtiesTest::EngineTest::Upcaser
          end
        end
      RUBY

      boot_rails

      Rails::Application.routes.draw do |map|
        mount(Bukkits::Engine => "/bukkits")
      end

      env = Rack::MockRequest.env_for("/bukkits")
      response = Rails::Application.call(env)

      assert_equal "HELLO WORLD", response[2]
    end

    test "it provides routes as default endpoint" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      boot_rails

      Bukkits::Engine.routes.draw do |map|
        match "/foo" => lambda { |env| [200, {'Content-Type' => 'text/html'}, 'foo'] }
      end

      Rails::Application.routes.draw do |map|
        mount(Bukkits::Engine => "/bukkits")
      end

      env = Rack::MockRequest.env_for("/bukkits/foo")
      response = Rails::Application.call(env)

      assert_equal "foo", response[2]
    end

    test "engine can load its own plugins" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            paths.vendor.plugins = "#{File.join(@plugin.path, "lib/bukkits/plugins")}"
          end
        end
      RUBY

      @plugin.write "lib/bukkits/plugins/yaffle/init.rb", <<-RUBY
        Bukkits::Engine.config.yaffle_loaded = true
      RUBY

      boot_rails

      assert Bukkits::Engine.config.yaffle_loaded
    end
  end
end
