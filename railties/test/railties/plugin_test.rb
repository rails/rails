require "isolation/abstract_unit"
require "railties/shared_tests"

module RailtiesTest
  class PluginSpecificTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation
    include SharedTests

    def setup
      build_app

      @plugin = plugin "bukkits", "::LEVEL = config.log_level" do |plugin|
        plugin.write "lib/bukkits.rb", "class Bukkits; end"
      end
    end

    test "it loads the plugin's init.rb file" do
      boot_rails
      assert_equal "loaded", BUKKITS
    end

    test "the init.rb file has access to the config object" do
      boot_rails
      assert_equal :debug, LEVEL
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
        assert_equal '"bukkits" is a Railtie/Engine and cannot be installed as plugin', e.message
      end

      assert rescued, "Expected boot rails to fail"
    end
  end
end
