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

    test "adding an unknown framework raises an error" do
      class MyApp < Rails::Application
        config.frameworks << :action_foo
      end

      assert_raises RuntimeError do
        MyApp.new
      end
    end

    test "eager loading loads parent classes before children" do
      app_file "lib/zoo.rb", <<-ZOO
        class Zoo ; include ReptileHouse ; end
      ZOO
      app_file "lib/zoo/reptile_house.rb", <<-ZOO
        module Zoo::ReptileHouse ; end
      ZOO

      Rails::Initializer.run do |config|
        config.eager_load_paths = "#{app_path}/lib"
      end

      assert Zoo
    end

    test "setting another default locale" do
      Rails::Initializer.run do |config|
        config.i18n.default_locale = :de
      end
      assert_equal :de, I18n.default_locale
    end

    test "load environment with global" do
      app_file "config/environments/development.rb", "$initialize_test_set_from_env = 'success'"
      assert_nil $initialize_test_set_from_env
      Rails::Initializer.run { }
      assert_equal "success", $initialize_test_set_from_env
    end
  end
end