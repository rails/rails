# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  class FrameworksTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include EnvHelpers

    def setup
      build_app
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    # AC & AM
    test "set load paths set only if action controller or action mailer are in use" do
      assert_nothing_raised do
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
      assert_equal expanded_path, ActionController::Base.view_paths[0].to_s
      assert_equal expanded_path, ActionMailer::Base.view_paths[0].to_s
    end

    test "allows me to configure default URL options for ActionMailer" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.action_mailer.default_url_options = { :host => "test.rails" }
        end
      RUBY

      require "#{app_path}/config/environment"
      assert_equal "test.rails", ActionMailer::Base.default_url_options[:host]
    end

    test "includes URL helpers as action methods" do
      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
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
      assert Foo.method_defined?(:foo_url)
      assert Foo.method_defined?(:main_app)
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
        Rails.application.routes.draw do
          get "/:controller(/:action)"
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods

      get "/foo/included_helpers"
      assert_equal "from_app_helper from_foo_helper", last_response.body

      get "/foo/not_included_helper"
      assert_equal "false", last_response.body
    end

    test "action_controller api executes using all the middleware stack" do
      add_to_config "config.api_only = true"

      app_file "app/controllers/application_controller.rb", <<-RUBY
        class ApplicationController < ActionController::API
        end
      RUBY

      app_file "app/controllers/omg_controller.rb", <<-RUBY
        class OmgController < ApplicationController
          def show
            render json: { omg: 'omg' }
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/:controller(/:action)"
        end
      RUBY

      require "rack/test"
      extend Rack::Test::Methods

      get "omg/show"
      assert_equal '{"omg":"omg"}', last_response.body
    end

    # AD
    test "action_dispatch extensions are applied to ActionDispatch" do
      add_to_config "config.action_dispatch.tld_length = 2"
      require "#{app_path}/config/environment"
      assert_equal 2, ActionDispatch::Http::URL.tld_length
    end

    test "assignment config.encoding to default_charset" do
      charset = "Shift_JIS"
      add_to_config "config.encoding = '#{charset}'"
      require "#{app_path}/config/environment"
      assert_equal charset, ActionDispatch::Response.default_charset
    end

    test "URL builder is configured to use HTTPS when force_ssl is on" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.force_ssl = true
        end
      RUBY

      require "#{app_path}/config/environment"
      assert_equal true, ActionDispatch::Http::URL.secure_protocol
    end

    # AS
    test "if there's no config.active_support.bare, all of ActiveSupport is required" do
      use_frameworks []
      require "#{app_path}/config/environment"
      assert_nothing_raised { [1, 2, 3].sample }
    end

    test "config.active_support.bare does not require all of ActiveSupport" do
      add_to_config "config.active_support.bare = true"

      use_frameworks []

      Dir.chdir("#{app_path}/app") do
        require "#{app_path}/config/environment"
        assert_raises(NoMethodError) { "hello".exclude? "lo" }
      end
    end

    # AR
    test "active_record extensions are applied to ActiveRecord" do
      add_to_config "config.active_record.table_name_prefix = 'tbl_'"
      require "#{app_path}/config/environment"
      assert_equal "tbl_", ActiveRecord::Base.table_name_prefix
    end

    test "database middleware doesn't initialize when activerecord is not in frameworks" do
      use_frameworks []
      require "#{app_path}/config/environment"
      assert !defined?(ActiveRecord::Base) || ActiveRecord.autoload?(:Base)
    end

    test "can boot with an unhealthy database" do
      rails %w(generate model post title:string)

      switch_env("DATABASE_URL", "mysql2://127.0.0.1:1") do
        require "#{app_path}/config/environment"
      end
    end

    test "use schema cache dump" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      require "#{app_path}/config/environment"

      assert ActiveRecord::Base.connection.schema_cache.data_sources("posts")
    ensure
      ActiveRecord::Base.connection.drop_table("posts", if_exists: true) # force drop posts table for test.
    end

    test "expire schema cache dump" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      require "#{app_path}/config/environment"
      assert_not ActiveRecord::Base.connection.schema_cache.data_sources("posts")
    end

    test "expire schema cache dump if the version can't be checked because the database is unhealthy" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      ActiveRecord::Migrator.stub(:current_version, -> { raise ActiveRecord::ConnectionNotEstablished }) do
        require "#{app_path}/config/environment"
        assert_not ActiveRecord::Base.connection_pool.schema_cache.data_sources("posts")
      end
    end

    test "does not expire schema cache dump if check_schema_cache_dump_version is false" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      require "#{app_path}/config/environment"
      assert ActiveRecord::Base.connection_pool.schema_cache.data_sources("posts")
    end

    test "does not expire schema cache dump if check_schema_cache_dump_version is false and the database unhealthy" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      ActiveRecord::Migrator.stub(:current_version, -> { raise ActiveRecord::ConnectionNotEstablished }) do
        require "#{app_path}/config/environment"

        assert ActiveRecord::Base.connection_pool.schema_cache.data_sources("posts")
      end
    end

    test "active record establish_connection uses Rails.env if DATABASE_URL is not set" do
      require "#{app_path}/config/environment"
      orig_database_url = ENV.delete("DATABASE_URL")
      orig_rails_env, Rails.env = Rails.env, "development"
      ActiveRecord::Base.establish_connection
      assert ActiveRecord::Base.connection
      assert_match(/#{ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary").database}/, ActiveRecord::Base.connection_db_config.database)
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
      assert_match(/#{db_config.database}/, ActiveRecord::Base.connection_db_config.database)
    ensure
      ActiveRecord::Base.remove_connection
      ENV["DATABASE_URL"] = orig_database_url if orig_database_url
      Rails.env = orig_rails_env if orig_rails_env
    end

    test "active record establish_connection uses DATABASE_URL even if Rails.env is set" do
      require "#{app_path}/config/environment"
      orig_database_url = ENV.delete("DATABASE_URL")
      orig_rails_env, Rails.env = Rails.env, "development"
      database_url_db_name = "db/database_url_db.sqlite3"
      ENV["DATABASE_URL"] = "sqlite3:#{database_url_db_name}"
      ActiveRecord::Base.establish_connection
      assert ActiveRecord::Base.connection
      assert_match(/#{database_url_db_name}/, ActiveRecord::Base.connection_db_config.database)
    ensure
      ActiveRecord::Base.remove_connection
      ENV["DATABASE_URL"] = orig_database_url if orig_database_url
      Rails.env = orig_rails_env if orig_rails_env
    end

    test "connections checked out during initialization are returned to the pool" do
      app_file "config/initializers/active_record.rb", <<-RUBY
        ActiveRecord::Base.connection
      RUBY
      require "#{app_path}/config/environment"
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
    end
  end
end
