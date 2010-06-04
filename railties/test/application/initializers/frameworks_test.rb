require "isolation/abstract_unit"

module ApplicationTests
  class FrameworlsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    # AC & AM
    test "set load paths set only if action controller or action mailer are in use" do
      assert_nothing_raised NameError do
        add_to_config <<-RUBY
          config.root = "#{app_path}"
        RUBY

        use_frameworks []
        require "#{app_path}/config/environment"
      end
    end

    test "sets action_controller and action_mailer load paths" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      require "#{app_path}/config/environment"
      ActionController::Base.view_paths.include?(File.expand_path("app/views", app_path))
      ActionMailer::Base.view_paths.include?(File.expand_path("app/views", app_path))
    end

    test "allows me to configure default url options for ActionMailer" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails::Application.configure do
          config.action_mailer.default_url_options = { :host => "test.rails" }
        end
      RUBY

      require "#{app_path}/config/environment"
      assert "test.rails", ActionMailer::Base.default_url_options[:host]
    end

    # AS
    test "if there's no config.active_support.bare, all of ActiveSupport is required" do
      use_frameworks []
      require "#{app_path}/config/environment"
      assert_nothing_raised { [1,2,3].sample }
    end

    test "config.active_support.bare does not require all of ActiveSupport" do
      add_to_config "config.active_support.bare = true"

      use_frameworks []

      Dir.chdir("#{app_path}/app") do
        require "#{app_path}/config/environment"
        assert_raises(NoMethodError) { [1,2,3].sample }
      end
    end

    # AR
    test "database middleware doesn't initialize when session store is not active_record" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.session_store :cookie_store, { :key => "blahblahblah" }
      RUBY
      require "#{app_path}/config/environment"

      assert !Rails.application.config.middleware.include?(ActiveRecord::SessionStore)
    end

    test "database middleware initializes when session store is active record" do
      add_to_config "config.session_store :active_record_store"

      require "#{app_path}/config/environment"

      expects = [ActiveRecord::ConnectionAdapters::ConnectionManagement, ActiveRecord::QueryCache, ActiveRecord::SessionStore]
      middleware = Rails.application.config.middleware.map { |m| m.klass }
      assert_equal expects, middleware & expects
    end

    test "active_record extensions are applied to ActiveRecord" do
      add_to_config "config.active_record.table_name_prefix = 'tbl_'"
      require "#{app_path}/config/environment"
      assert_equal 'tbl_', ActiveRecord::Base.table_name_prefix
    end

    test "database middleware doesn't initialize when activerecord is not in frameworks" do
      use_frameworks []
      require "#{app_path}/config/environment"
      assert_nil defined?(ActiveRecord::Base)
    end
  end
end
