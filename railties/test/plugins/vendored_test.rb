require "isolation/abstract_unit"

module PluginsTest
  class VendoredTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app

      @plugin = plugin "bukkits", "::LEVEL = config.log_level" do |plugin|
        plugin.write "lib/bukkits.rb", "class Bukkits; end"
      end
    end

    def boot_rails
      super
      require "#{app_path}/config/environment"
    end

    test "it loads the plugin's init.rb file" do
      boot_rails
      assert_equal "loaded", BUKKITS
    end

    test "the init.rb file has access to the config object" do
      boot_rails
      assert_equal :debug, LEVEL
    end

    test "the plugin puts its lib directory on the load path" do
      boot_rails
      require "bukkits"
      assert_equal "Bukkits", Bukkits.name
    end

    test "plugin paths get added to the AS::Dependency list" do
      boot_rails
      assert_equal "Bukkits", Bukkits.name
    end

    test "plugin constants do not get reloaded by default" do
      boot_rails
      assert_equal "Bukkits", Bukkits.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/bukkits.rb")
      assert_nothing_raised { Bukkits }
    end

    test "plugin constants get reloaded if config.reload_plugins is set" do
      add_to_config <<-RUBY
        config.reload_plugins = true
      RUBY

      boot_rails

      assert_equal "Bukkits", Bukkits.name
      ActiveSupport::Dependencies.clear
      @plugin.delete("lib/bukkits.rb")
      assert_raises(NameError) { Bukkits }
    end

    test "plugin should work without init.rb" do
      @plugin.delete("init.rb")

      boot_rails

      require "bukkits"
      assert_nothing_raised { Bukkits }
    end

    test "the plugin puts its models directory on the load path" do
      @plugin.write "app/models/my_bukkit.rb", "class MyBukkit ; end"

      boot_rails

      assert_nothing_raised { MyBukkit }
    end

    test "the plugin puts is controllers directory on the load path" do
      @plugin.write "app/controllers/bukkit_controller.rb", "class BukkitController ; end"

      boot_rails

      assert_nothing_raised { BukkitController }
    end

    test "the plugin adds its view to the load path" do
      @plugin.write "app/controllers/bukkit_controller.rb", <<-RUBY
        class BukkitController < ActionController::Base
          def index
          end
        end
      RUBY

      @plugin.write "app/views/bukkit/index.html.erb", "Hello bukkits"

      boot_rails

      require "action_controller"
      require "rack/mock"
      response = BukkitController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal "Hello bukkits\n", response[2].body
    end

    test "the plugin adds helpers to the controller's views" do
      @plugin.write "app/controllers/bukkit_controller.rb", <<-RUBY
        class BukkitController < ActionController::Base
          def index
          end
        end
      RUBY

      @plugin.write "app/helpers/bukkit_helper.rb", <<-RUBY
        module BukkitHelper
          def bukkits
            "bukkits"
          end
        end
      RUBY

      @plugin.write "app/views/bukkit/index.html.erb", "Hello <%= bukkits %>"

      boot_rails

      require "rack/mock"
      response = BukkitController.action(:index).call(Rack::MockRequest.env_for("/"))
      assert_equal "Hello bukkits\n", response[2].body
    end

    test "routes.rb are added to the router" do
      @plugin.write "config/routes.rb", <<-RUBY
        class Sprokkit
          def self.call(env)
            [200, {'Content-Type' => 'text/html'}, ["I am a Sprokkit"]]
          end
        end

        ActionController::Routing::Routes.draw do
          match "/sprokkit", :to => Sprokkit
        end
      RUBY

      boot_rails
      require "rack/mock"
      response = Rails.application.call(Rack::MockRequest.env_for("/sprokkit"))
      assert_equal "I am a Sprokkit", response[2].join
    end
  end

  class VendoredOrderingTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      $arr = []
      plugin "a_plugin", "$arr << :a"
      plugin "b_plugin", "$arr << :b"
      plugin "c_plugin", "$arr << :c"
    end

    def boot_rails
      super
      require "#{app_path}/config/environment"
    end

    test "plugins are loaded alphabetically by default" do
      boot_rails
      assert_equal [:a, :b, :c], $arr
    end

    test "if specified, only those plugins are loaded" do
      add_to_config "config.plugins = [:b_plugin]"
      boot_rails
      assert_equal [:b], $arr
    end

    test "the plugins are initialized in the order they are specified" do
      add_to_config "config.plugins = [:b_plugin, :a_plugin]"
      boot_rails
      assert_equal [:b, :a], $arr
    end

    test "if :all is specified, the remaining plugins are loaded in alphabetical order" do
      add_to_config "config.plugins = [:c_plugin, :all]"
      boot_rails
      assert_equal [:c, :a, :b], $arr
    end

    test "if :all is at the beginning, it represents the plugins not otherwise specified" do
      add_to_config "config.plugins = [:all, :b_plugin]"
      boot_rails
      assert_equal [:a, :c, :b], $arr
    end

    test "plugin order array is strings" do
      add_to_config "config.plugins = %w( c_plugin all )"
      boot_rails
      assert_equal [:c, :a, :b], $arr
    end
  end
end
