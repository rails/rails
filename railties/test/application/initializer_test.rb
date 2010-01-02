require "isolation/abstract_unit"

module ApplicationTests
  class InitializerTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    test "initializing an application adds the application paths to the load path" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      assert $:.include?("#{app_path}/app/models")
    end

    test "eager loading loads parent classes before children" do
      app_file "lib/zoo.rb", <<-ZOO
        class Zoo ; include ReptileHouse ; end
      ZOO
      app_file "lib/zoo/reptile_house.rb", <<-ZOO
        module Zoo::ReptileHouse ; end
      ZOO

      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.eager_load_paths = "#{app_path}/lib"
      RUBY

      require "#{app_path}/config/environment"

      assert Zoo
    end

    test "load environment with global" do
      app_file "config/environments/development.rb", "$initialize_test_set_from_env = 'success'"
      assert_nil $initialize_test_set_from_env
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY
      require "#{app_path}/config/environment"
      assert_equal "success", $initialize_test_set_from_env
    end

    test "action_controller load paths set only if action controller in use" do
      assert_nothing_raised NameError do
        add_to_config <<-RUBY
          config.root = "#{app_path}"
        RUBY

        use_frameworks []
        require "#{app_path}/config/environment"
      end
    end

    test "after_initialize block works correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      RUBY
      require "#{app_path}/config/environment"

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    test "after_initialize block works correctly when no block is passed" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.after_initialize { $test_after_initialize_block1 = "success" }
        config.after_initialize # don't pass a block, this is what we're testing!
        config.after_initialize { $test_after_initialize_block2 = "congratulations" }
      RUBY
      require "#{app_path}/config/environment"

      assert_equal "success", $test_after_initialize_block1
      assert_equal "congratulations", $test_after_initialize_block2
    end

    # i18n
    test "setting another default locale" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.i18n.default_locale = :de
      RUBY
      require "#{app_path}/config/environment"

      assert_equal :de, I18n.default_locale
    end

    test "no config locales dir present should return empty load path" do
      FileUtils.rm_rf "#{app_path}/config/locales"
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY
      require "#{app_path}/config/environment"

      assert_equal [], Rails.application.config.i18n.load_path
    end

    test "config locales dir present should be added to load path" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      assert_equal ["#{app_path}/config/locales/en.yml"],  Rails.application.config.i18n.load_path
    end

    test "config defaults should be added with config settings" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.i18n.load_path << "my/other/locale.yml"
      RUBY
      require "#{app_path}/config/environment"

      assert_equal [
        "#{app_path}/config/locales/en.yml", "my/other/locale.yml"
      ], Rails.application.config.i18n.load_path
    end

    # DB middleware
    test "database middleware doesn't initialize when session store is not active_record" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.action_controller.session_store = :cookie_store
      RUBY
      require "#{app_path}/config/environment"

      assert !Rails.application.config.middleware.include?(ActiveRecord::SessionStore)
    end

    test "database middleware initializes when session store is active record" do
      add_to_config "config.action_controller.session_store = :active_record_store"

      require "#{app_path}/config/environment"

      expects = [ActiveRecord::ConnectionAdapters::ConnectionManagement, ActiveRecord::QueryCache, ActiveRecord::SessionStore]
      middleware = Rails.application.config.middleware.map { |m| m.klass }
      assert_equal expects, middleware & expects
    end

    test "Rails.root should be a Pathname" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY
      require "#{app_path}/config/environment"
      assert_instance_of Pathname, Rails.root
    end
  end

  class InitializerCustomFrameworkExtensionsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    test "database middleware doesn't initialize when activerecord is not in frameworks" do
      use_frameworks []
      require "#{app_path}/config/environment"

      assert_nil defined?(ActiveRecord)
    end
  end
end
