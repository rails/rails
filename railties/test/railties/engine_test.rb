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

    def teardown
      teardown_app
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
  end
end
