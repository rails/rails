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

    def reload_config
      :reload_engines
    end

    test "Rails::Engine itself does not respond to config" do
      boot_rails
      assert !Rails::Engine.respond_to?(:config)
    end
  end
end
