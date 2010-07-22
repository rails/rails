require "isolation/abstract_unit"
require "railties/shared_tests"
require 'stringio'

module RailtiesTest
  class EngineTest < Test::Unit::TestCase
    # TODO: it's copied from generators/test_case, maybe make a module with such helpers?
    def capture(stream)
      begin
        stream = stream.to_s
        eval "$#{stream} = StringIO.new"
        yield
        result = eval("$#{stream}").string
      ensure
        eval("$#{stream} = #{stream.upcase}")
      end

      result
    end

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

      assert index > initializers.index { |i| i.name == :load_config_initializers }
      assert index > initializers.index { |i| i.name == :engines_blank_point }
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

      Rails.application.routes.draw do |map|
        mount(Bukkits::Engine => "/bukkits")
      end

      env = Rack::MockRequest.env_for("/bukkits")
      response = Rails.application.call(env)

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

      Rails.application.routes.draw do |map|
        mount(Bukkits::Engine => "/bukkits")
      end

      env = Rack::MockRequest.env_for("/bukkits/foo")
      response = Rails.application.call(env)

      assert_equal "foo", response[2]
    end

    test "engine can load its own plugins" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.yaffle_loaded = true
      RUBY

      boot_rails

      assert Bukkits::Engine.config.yaffle_loaded
    end

    test "engine does not load plugins that already exists in application" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.engine_yaffle_loaded = true
      RUBY

      app_file "vendor/plugins/yaffle/init.rb", <<-RUBY
        config.app_yaffle_loaded = true
      RUBY

      warnings = capture(:stderr) { boot_rails }

      assert !warnings.empty?
      assert !Bukkits::Engine.config.respond_to?(:engine_yaffle_loaded)
      assert Rails.application.config.app_yaffle_loaded
    end

    test "it loads its environment file" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
          end
        end
      RUBY

      @plugin.write "config/environments/development.rb", <<-RUBY
        Bukkits::Engine.configure do
          config.environment_loaded = true
        end
      RUBY

      boot_rails

      assert Bukkits::Engine.config.environment_loaded
    end

    test "it passes router in env" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            endpoint lambda { |env| [200, {'Content-Type' => 'text/html'}, 'hello'] }
          end
        end
      RUBY

      boot_rails

      env = Rack::MockRequest.env_for("/")
      response = Bukkits::Engine.call(env)

      assert_equal Bukkits::Engine.routes, env['action_dispatch.routes']

      env = Rack::MockRequest.env_for("/")
      response = Rails.application.call(env)

      assert_equal Rails.application.routes, env['action_dispatch.routes']
    end

    test "it allows to set asset_path" do
      @plugin.write "lib/bukkits.rb", <<-RUBY
        class Bukkits
          class Engine < ::Rails::Engine
            config.asset_path = "/bukkits%s"
          end
        end
      RUBY


      @plugin.write "config/routes.rb", <<-RUBY
        Bukkits::Engine.routes.draw do
          match "/foo" => "foo#index"
        end
      RUBY

      @plugin.write "app/controllers/foo_controller.rb", <<-RUBY
        class FooController < ActionController::Base
          def index
            render :index
          end
        end
      RUBY

      @plugin.write "app/views/foo/index.html.erb", <<-RUBY
        <%= compute_public_path("/foo", "") %>
        <%= image_path("foo.png") %>
        <%= javascript_include_tag("foo") %>
        <%= stylesheet_link_tag("foo") %>
      RUBY


      app_file "app/controllers/bar_controller.rb", <<-RUBY
        class BarController < ActionController::Base
          def index
            render :index
          end
        end
      RUBY

      app_file "app/views/bar/index.html.erb", <<-RUBY
        <%= compute_public_path("/foo", "") %>
      RUBY

      add_to_config 'config.asset_path = "/omg%s"'

      boot_rails

      env = Rack::MockRequest.env_for("/foo")
      response = Bukkits::Engine.call(env)
      stripped_body = response[2].body.split("\n").map(&:strip).join("\n")

      expected =  "/omg/bukkits/foo\n" +
                  "/omg/bukkits/images/foo.png\n" +
                  "<script src=\"/omg/bukkits/javascripts/foo.js\" type=\"text/javascript\"></script>\n" +
                  "<link href=\"/omg/bukkits/stylesheets/foo.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />"
      assert_equal expected, stripped_body

    end
  end
end
