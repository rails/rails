require "isolation/abstract_unit"

module ApplicationTests
  class FrameworksTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
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

      expanded_path = File.expand_path("app/views", app_path)
      assert_equal ActionController::Base.view_paths[0].to_s, expanded_path
      assert_equal ActionMailer::Base.view_paths[0].to_s, expanded_path
    end

    test "allows me to configure default url options for ActionMailer" do
      app_file "config/environments/development.rb", <<-RUBY
        AppTemplate::Application.configure do
          config.action_mailer.default_url_options = { :host => "test.rails" }
        end
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "test.rails", ActionMailer::Base.default_url_options[:host]
    end

    test "does not include url helpers as action methods" do
      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          get "/foo", :to => lambda { |env| [200, {}, []] }, :as => :foo
        end
      RUBY

      app_file "app/mailers/foo.rb", <<-RUBY
        class Foo < ActionMailer::Base
          def notify
          end
        end
      RUBY

      require "#{app_path}/config/environment"
      assert Foo.method_defined?(:foo_path)
      assert Foo.method_defined?(:main_app)
      assert_equal ["notify"], Foo.action_methods
    end

    test "allows to not load all helpers for controllers" do
      add_to_config "config.action_controller.include_all_helpers = false"

      app_file "app/controllers/application_controller.rb", <<-RUBY
        class ApplicationController < ActionController::Base
        end
      RUBY

      app_file "app/controllers/foo_controller.rb", <<-RUBY
        class FooController < ApplicationController
          def included_helpers
            render :inline => "<%= from_app_helper -%> <%= from_foo_helper %>"
          end

          def not_included_helper
            render :inline => "<%= respond_to?(:from_bar_helper) -%>"
          end
        end
      RUBY

      app_file "app/helpers/application_helper.rb", <<-RUBY
        module ApplicationHelper
          def from_app_helper
            "from_app_helper"
          end
        end
      RUBY

      app_file "app/helpers/foo_helper.rb", <<-RUBY
        module FooHelper
          def from_foo_helper
            "from_foo_helper"
          end
        end
      RUBY

      app_file "app/helpers/bar_helper.rb", <<-RUBY
        module BarHelper
          def from_bar_helper
            "from_bar_helper"
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        AppTemplate::Application.routes.draw do
          match "/:controller(/:action)"
        end
      RUBY

      require 'rack/test'
      extend Rack::Test::Methods

      get "/foo/included_helpers"
      assert_equal "from_app_helper from_foo_helper", last_response.body

      get "/foo/not_included_helper"
      assert_equal "false", last_response.body
    end

    # AD
    test "action_dispatch extensions are applied to ActionDispatch" do
      add_to_config "config.action_dispatch.tld_length = 2"
      require "#{app_path}/config/environment"
      assert_equal 2, ActionDispatch::Http::URL.tld_length
    end

    test "assignment config.encoding to default_charset" do
      charset = "ruby".respond_to?(:force_encoding) ? 'Shift_JIS' : 'UTF8'
      add_to_config "config.encoding = '#{charset}'"
      require "#{app_path}/config/environment"
      assert_equal charset, ActionDispatch::Response.default_charset
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
        assert_raises(NoMethodError) { [1,2,3].forty_two }
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

    test "active record establish_connection uses Rails.env if DATABASE_URL is not set" do
      begin
        require "#{app_path}/config/environment"
        orig_database_url = ENV.delete("DATABASE_URL")
        orig_rails_env, Rails.env = Rails.env, 'development'

        ActiveRecord::Base.establish_connection

        assert ActiveRecord::Base.connection
        assert_match /#{ActiveRecord::Base.configurations[Rails.env]['database']}/, ActiveRecord::Base.connection_config[:database]
      ensure
        ActiveRecord::Base.remove_connection
        ENV["DATABASE_URL"] = orig_database_url if orig_database_url
        Rails.env = orig_rails_env if orig_rails_env
      end
    end

    test "active record establish_connection uses DATABASE_URL even if Rails.env is set" do
      begin
        require "#{app_path}/config/environment"
        orig_database_url = ENV.delete("DATABASE_URL")
        orig_rails_env, Rails.env = Rails.env, 'development'
        database_url_db_name = "db/database_url_db.sqlite3"
        ENV["DATABASE_URL"] = "sqlite3://:@localhost/#{database_url_db_name}"

        ActiveRecord::Base.establish_connection

        assert ActiveRecord::Base.connection
        assert_match /#{database_url_db_name}/, ActiveRecord::Base.connection_config[:database]
      ensure
        ActiveRecord::Base.remove_connection
        ENV["DATABASE_URL"] = orig_database_url if orig_database_url
        Rails.env = orig_rails_env if orig_rails_env
      end
    end
  end
end
