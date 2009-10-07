require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    test "initializers only ever run once" do
      class MyApp < Rails::Application
        initializer :counter do
          $counter += 1
        end
      end

      $counter = 0
      MyApp.initializers[:counter].run
      MyApp.initializers[:counter].run

      assert_equal 1, $counter
    end
  end
end