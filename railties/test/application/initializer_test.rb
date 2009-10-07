require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    test "initializing an application initializes rails" do
      class MyApp < Rails::Application ; end

      if RUBY_VERSION < '1.9'
        $KCODE = ''
        MyApp.new
        assert_equal 'UTF8', $KCODE
      else
        Encoding.default_external = Encoding::US_ASCII
        MyApp.new
        assert_equal Encoding::UTF_8, Encoding.default_external
      end
    end

    test "initializing an application adds the application paths to the load path" do
      class MyApp < Rails::Application ; end

      MyApp.new
      assert $:.include?("#{app_path}/app/models")
    end
  end
end