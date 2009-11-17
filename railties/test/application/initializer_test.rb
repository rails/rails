require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      require "rails"
    end

    test "initializing an application initializes rails" do
      Rails::Initializer.run do |config|
        config.root = app_path
      end

      if RUBY_VERSION < '1.9'
        $KCODE = ''
        Rails.initialize!
        assert_equal 'UTF8', $KCODE
      else
        Encoding.default_external = Encoding::US_ASCII
        Rails.initialize!
        assert_equal Encoding::UTF_8, Encoding.default_external
      end
    end

    test "initializing an application adds the application paths to the load path" do
      Rails::Initializer.run do |config|
        config.root = app_path
      end

      Rails.initialize!
      assert $:.include?("#{app_path}/app/models")
    end

    test "adding an unknown framework raises an error" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.frameworks << :action_foo
      end

      assert_raises RuntimeError do
        Rails.initialize!
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
        config.root = app_path
        config.eager_load_paths = "#{app_path}/lib"
      end

      Rails.initialize!

      assert Zoo
    end

    test "load environment with global" do
      app_file "config/environments/development.rb", "$initialize_test_set_from_env = 'success'"
      assert_nil $initialize_test_set_from_env
      Rails::Initializer.run { |config| config.root = app_path }
      Rails.initialize!
      assert_equal "success", $initialize_test_set_from_env
    end

    test "action_controller load paths set only if action controller in use" do
      assert_nothing_raised NameError do
        Rails::Initializer.run do |config|
          config.root = app_path
          config.frameworks = []
        end
        Rails.initialize!
      end
    end

    test "after_initialize block works correctly" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      end
      Rails.initialize!

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    test "after_initialize block works correctly when no block is passed" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize # don't pass a block, this is what we're testing!
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      end
      Rails.initialize!

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    # i18n
    test "setting another default locale" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.i18n.default_locale = :de
      end
      Rails.initialize!

      assert_equal :de, I18n.default_locale
    end

    test "no config locales dir present should return empty load path" do
      FileUtils.rm_rf "#{app_path}/config/locales"
      Rails::Initializer.run do |c|
        c.root = app_path
        assert_equal [], c.i18n.load_path
      end
    end

    test "config locales dir present should be added to load path" do
      Rails::Initializer.run do |c|
        c.root = app_path
        assert_equal ["#{app_path}/config/locales/en.yml"], c.i18n.load_path
      end
    end

    test "config defaults should be added with config settings" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.i18n.load_path << "my/other/locale.yml"
      end

      assert_equal [
        "#{app_path}/config/locales/en.yml", "my/other/locale.yml"
      ], Rails.application.config.i18n.load_path
    end

    # DB middleware
    test "database middleware doesn't initialize when session store is not active_record" do
      Rails::Initializer.run do |config|
        config.root = app_path
        config.action_controller.session_store = :cookie_store
      end
      Rails.initialize!

      assert !Rails.application.config.middleware.include?(ActiveRecord::SessionStore)
    end

    test "database middleware doesn't initialize when activerecord is not in frameworks" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.frameworks = []
      end
      assert_equal [], Rails.application.config.middleware
    end

    test "database middleware initializes when session store is active record" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.action_controller.session_store = :active_record_store
      end
      Rails.initialize!

      expects = [ActiveRecord::ConnectionAdapters::ConnectionManagement, ActiveRecord::QueryCache, ActiveRecord::SessionStore]
      middleware = Rails.application.config.middleware.map { |m| m.klass }
      assert_equal expects, middleware & expects
    end

    test "ensure database middleware doesn't use action_controller on initializing" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.frameworks -= [:action_controller]
        c.action_controller.session_store = :active_record_store
      end
      Rails.initialize!

      assert !Rails.application.config.middleware.include?(ActiveRecord::SessionStore)
    end

    # Pathview test
    test "load view paths doesn't perform anything when action_view not in frameworks" do
      Rails::Initializer.run do |c|
        c.root = app_path
        c.frameworks -= [:action_view]
      end
      Rails.initialize!

      assert_equal nil, ActionMailer::Base.template_root
      assert_equal [], ActionController::Base.view_paths
    end

    test "Rails.root should be a Pathname" do
      Rails::Initializer.run do |c|
        c.root = app_path
      end
      Rails.initialize!
      assert_instance_of Pathname, Rails.root
    end
  end
end