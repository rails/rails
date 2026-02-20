# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "env_helpers"

class ::MyMailInterceptor
  def self.delivering_email(email); email; end
end

class ::MyOtherMailInterceptor < ::MyMailInterceptor; end

class ::MyPreviewMailInterceptor
  def self.previewing_email(email); email; end
end

class ::MyOtherPreviewMailInterceptor < ::MyPreviewMailInterceptor; end

class ::MyMailObserver
  def self.delivered_email(email); email; end
end

class ::MyOtherMailObserver < ::MyMailObserver; end

class ::MySafeListSanitizer < Rails::HTML4::SafeListSanitizer; end

class ::MySanitizerVendor < ::Rails::HTML::Sanitizer
  def self.safe_list_sanitizer
    ::MySafeListSanitizer
  end
end

class ::MyCustomKeyProvider
  attr_reader :primary_key
  def initialize(primary_key); @primary_key = primary_key; end
end

class ::MyOldKeyProvider; end

module ApplicationTests
  class ConfigurationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include EnvHelpers

    def new_app
      File.expand_path("#{app_path}/../new_app")
    end

    def copy_app
      FileUtils.cp_r(app_path, new_app)
    end

    def switch_development_hosts_to(*hosts)
      old_development_hosts = ENV["RAILS_DEVELOPMENT_HOSTS"]
      ENV["RAILS_DEVELOPMENT_HOSTS"] = hosts.join(",")
      yield
    ensure
      ENV["RAILS_DEVELOPMENT_HOSTS"] = old_development_hosts
    end

    def setup
      build_app
      suppress_default_config
    end

    def teardown
      teardown_app
      FileUtils.rm_rf(new_app) if File.directory?(new_app)
    end

    def suppress_default_config
      FileUtils.mv("#{app_path}/config/environments", "#{app_path}/config/__environments__")
    end

    def restore_default_config
      FileUtils.rm_rf("#{app_path}/config/environments")
      FileUtils.mv("#{app_path}/config/__environments__", "#{app_path}/config/environments")
      remove_from_env_config "production", "config.log_level = :error"
    end

    test "Rails.env does not set the RAILS_ENV environment variable which would leak out into rake tasks" do
      require "rails"

      switch_env "RAILS_ENV", nil do
        Rails.env = "development"
        assert_equal "development", Rails.env
        assert_nil ENV["RAILS_ENV"]
      end
    end

    test "Rails.env falls back to development if RAILS_ENV is blank and RACK_ENV is nil" do
      with_rails_env("") do
        assert_equal "development", Rails.env
      end
    end

    test "Rails.env falls back to development if RACK_ENV is blank and RAILS_ENV is nil" do
      with_rack_env("") do
        assert_equal "development", Rails.env
      end
    end

    test "By default logs tags are not set in development" do
      restore_default_config

      with_rails_env "development" do
        app "development"
        assert_predicate Rails.application.config.log_tags, :blank?
      end
    end

    test "By default logs are tagged with :request_id in production" do
      restore_default_config

      with_rails_env "production" do
        app "production"
        assert_equal [:request_id], Rails.application.config.log_tags
      end
    end

    test "lib dir is on LOAD_PATH during config" do
      app_file "lib/my_logger.rb", <<-RUBY
        require "logger"
        class MyLogger < ::Logger
        end
      RUBY
      add_to_top_of_config <<-RUBY
        require "my_logger"
        config.logger = MyLogger.new STDOUT
      RUBY

      app "development"

      assert_equal "MyLogger", Rails.application.config.logger.class.name
    end

    test "raises an error if cache does not support recyclable cache keys" do
      restore_default_config
      add_to_env_config "production", "config.cache_store = Class.new {}.new"
      add_to_env_config "production", "config.active_record.cache_versioning = true"

      error = assert_raise(RuntimeError) do
        app "production"
      end

      assert_match(/You're using a cache/, error.message)
    end

    test "renders an exception on pending migration" do
      add_to_config <<-RUBY
        config.active_record.migration_error    = :page_load
        config.consider_all_requests_local      = true
        config.action_dispatch.show_exceptions  = :all
      RUBY

      app_file "db/migrate/20140708012246_create_user.rb", <<-RUBY
        class CreateUser < ActiveRecord::Migration::Current
          def change
            create_table :users
          end
        end
      RUBY

      app "development"

      begin
        ActiveRecord::Migrator.migrations_paths = ["#{app_path}/db/migrate"]

        get "/foo"
        assert_equal 500, last_response.status
        assert_match "ActiveRecord::PendingMigrationError", last_response.body

        assert_changes -> { File.exist?(File.join(app_path, "db", "schema.rb")) }, from: false, to: true do
          output = capture(:stdout) do
            post "/rails/actions", { error: "ActiveRecord::PendingMigrationError", action: "Run pending migrations", location: "/foo" }
          end

          assert_match(/\d{14}\s+CreateUser/, output)
        end

        assert_equal 302, last_response.status

        get "/foo"
        assert_equal 404, last_response.status
      ensure
        ActiveRecord::Migrator.migrations_paths = nil
      end
    end

    test "renders an exception on pending migration for multiple DBs" do
      add_to_config <<-RUBY
        config.active_record.migration_error    = :page_load
        config.consider_all_requests_local      = true
        config.action_dispatch.show_exceptions  = :all
      RUBY

      app_file "config/database.yml", <<-YAML
        <%= Rails.env %>:
          primary:
            adapter: sqlite3
            database: 'dev_db'
          other:
            adapter: sqlite3
            database: 'other_dev_db'
            migrations_paths: db/other_migrate
      YAML

      app_file "db/migrate/20140708012246_create_users.rb", <<-RUBY
        class CreateUsers < ActiveRecord::Migration::Current
          def change
            create_table :users
          end
        end
      RUBY

      app_file "db/other_migrate/20140708012247_create_blogs.rb", <<-RUBY
        class CreateBlogs < ActiveRecord::Migration::Current
          def change
            create_table :blogs
          end
        end
      RUBY

      app "development"

      begin
        ActiveRecord::Migrator.migrations_paths = ["#{app_path}/db/migrate", "#{app_path}/db/other_migrate"]

        get "/foo"
        assert_equal 500, last_response.status
        assert_match "ActiveRecord::PendingMigrationError", last_response.body

        assert_changes -> { File.exist?(File.join(app_path, "db", "schema.rb")) }, from: false, to: true do
          output = capture(:stdout) do
            post "/rails/actions", { error: "ActiveRecord::PendingMigrationError", action: "Run pending migrations", location: "/foo" }
          end

          assert_match(/\d{14}\s+CreateUsers/, output)
          assert_match(/\d{14}\s+CreateBlogs/, output)
        end

        assert_equal 302, last_response.status

        get "/foo"
        assert_equal 404, last_response.status
      ensure
        ActiveRecord::Migrator.migrations_paths = nil
      end
    end

    test "Rails.groups returns available groups" do
      require "rails"

      Rails.env = "development"
      assert_equal [:default, "development"], Rails.groups
      assert_equal [:default, "development", :assets], Rails.groups(assets: [:development])
      assert_equal [:default, "development", :another, :assets], Rails.groups(:another, assets: %w(development))

      Rails.env = "test"
      assert_equal [:default, "test"], Rails.groups(assets: [:development])

      with_env RAILS_GROUPS: "javascripts,stylesheets" do
        assert_equal [:default, "test", "javascripts", "stylesheets"], Rails.groups
      end
    end

    test "Rails.application is nil until app is initialized" do
      require "rails"
      assert_nil Rails.application
      app "development"
      assert_equal AppTemplate::Application.instance, Rails.application
    end

    test "Rails.application responds to all instance methods" do
      app "development"
      assert_equal Rails.application.routes_reloader, AppTemplate::Application.routes_reloader
      assert_kind_of ActiveSupport::MessageVerifiers, Rails.application.message_verifiers
      assert_kind_of ActiveSupport::Deprecation::Deprecators, Rails.application.deprecators
    end

    test "Rails::Application responds to paths" do
      app "development"
      assert_equal ["#{app_path}/app/views"], AppTemplate::Application.paths["app/views"].expanded
    end

    test "the application root is set correctly" do
      app "development"
      assert_equal Pathname.new(app_path), Rails.application.root
    end

    test "the application root can be seen from the application singleton" do
      app "development"
      assert_equal Pathname.new(app_path), AppTemplate::Application.root
    end

    test "the application root can be set" do
      copy_app
      add_to_config <<-RUBY
        config.root = '#{new_app}'
      RUBY

      use_frameworks []

      app "development"

      assert_equal Pathname.new(new_app), Rails.application.root
    end

    test "the application root is Dir.pwd if there is no config.ru" do
      File.delete("#{app_path}/config.ru")

      use_frameworks []

      Dir.chdir("#{app_path}") do
        app "development"
        assert_equal Pathname.new("#{app_path}"), Rails.application.root
      end
    end

    test "Rails.root should be a Pathname" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      app "development"

      assert_instance_of Pathname, Rails.root
    end

    test "Rails.public_path should be a Pathname" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      app "development"

      assert_instance_of Pathname, Rails.public_path
    end

    test "config.enable_reloading is !config.cache_classes" do
      app "development"

      config = Rails.application.config

      assert_equal !config.cache_classes, config.enable_reloading

      [true, false].each do |enabled|
        config.enable_reloading = enabled
        assert_equal enabled, config.enable_reloading
        assert_equal enabled, config.reloading_enabled?
        assert_equal enabled, !config.cache_classes
      end

      [true, false].each do |enabled|
        config.cache_classes = enabled
        assert_equal enabled, !config.enable_reloading
        assert_equal enabled, !config.reloading_enabled?
        assert_equal enabled, config.cache_classes
      end
    end

    test "does not eager load controllers state actions in development" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index;end
          def show;end
        end
      RUBY

      app "development"

      assert_nil PostsController.instance_variable_get(:@action_methods)
      assert_nil PostsController.instance_variable_get(:@view_context_class)
    end

    test "eager loads controllers state in production" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index;end
          def show;end
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
      RUBY

      app "production"

      assert_equal %w(index show).to_set, PostsController.instance_variable_get(:@action_methods)
      assert_not_nil PostsController.instance_variable_get(:@view_context_class)
    end

    test "does not eager load mailer actions in development" do
      app_file "app/mailers/posts_mailer.rb", <<-RUBY
        class PostsMailer < ActionMailer::Base
          def noop_email;end
        end
      RUBY

      app "development"

      assert_nil PostsMailer.instance_variable_get(:@action_methods)
    end

    test "eager loads mailer actions in production" do
      app_file "app/mailers/posts_mailer.rb", <<-RUBY
        class PostsMailer < ActionMailer::Base
          def noop_email;end
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
      RUBY

      app "production"

      assert_equal %w(noop_email).to_set, PostsMailer.instance_variable_get(:@action_methods)
    end

    test "does not eager load attribute methods in development" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      app_file "config/initializers/active_record.rb", <<-RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
          ActiveRecord::Migration.verbose = false
          ActiveRecord::Schema.define(version: 1) do
            create_table :posts do |t|
              t.string :title
            end
          end
        end
      RUBY

      app "development"

      assert_not_includes Post.instance_methods, :title
    end

    test "does not eager load attribute methods in production when the schema cache is empty and check_schema_cache_dump_version=false" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      app "production"

      assert_not_includes (Post.instance_methods - ActiveRecord::Base.instance_methods), :title
    end

    test "eager loads attribute methods in production when the schema cache is populated and check_schema_cache_dump_version=false" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      app_file "config/initializers/active_record.rb", <<-RUBY
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Schema.define(version: 1) do
          create_table :posts do |t|
            t.string :title
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      app_file "config/initializers/schema_cache.rb", <<-RUBY
      ActiveRecord::Base.schema_cache.add("posts")
      RUBY

      app "production"

      assert_includes (Post.instance_methods - ActiveRecord::Base.instance_methods), :title
    end

    test "does not eager loads attribute methods in production when the schema cache is populated and check_schema_cache_dump_version=true" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      app_file "config/initializers/active_record.rb", <<-RUBY
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Schema.define(version: 1) do
          create_table :posts do |t|
            t.string :title
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = true
      RUBY

      app_file "config/initializers/schema_cache.rb", <<-RUBY
      ActiveRecord::Base.schema_cache.add("posts")
      RUBY

      app "production"

      assert_not_includes (Post.instance_methods - ActiveRecord::Base.instance_methods), :title
    end

    test "application is always added to eager_load namespaces" do
      app "development"
      assert_includes Rails.application.config.eager_load_namespaces, AppTemplate::Application
    end

    test "the application can be eager loaded even when there are no frameworks" do
      FileUtils.rm_rf("#{app_path}/app/jobs/application_job.rb")
      FileUtils.rm_rf("#{app_path}/app/models/application_record.rb")
      FileUtils.rm_rf("#{app_path}/app/mailers/application_mailer.rb")
      FileUtils.rm_rf("#{app_path}/config/environments")
      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
      RUBY

      use_frameworks []

      assert_nothing_raised do
        app "development"
      end
    end

    test "propagates check_schema_cache_dump_version=true to ActiveRecord::ConnectionAdapters::SchemaReflection" do
      add_to_config <<-RUBY
        config.active_record.check_schema_cache_dump_version = true
      RUBY

      app "development"

      assert ActiveRecord::ConnectionAdapters::SchemaReflection.check_schema_cache_dump_version
    end

    test "propagates check_schema_cache_dump_version=false to ActiveRecord::ConnectionAdapters::SchemaReflection" do
      add_to_config <<-RUBY
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      app "development"

      assert_not ActiveRecord::ConnectionAdapters::SchemaReflection.check_schema_cache_dump_version
    end

    test "propagates use_schema_cache_dump=true to ActiveRecord::ConnectionAdapters::SchemaReflection" do
      add_to_config <<-RUBY
        config.active_record.use_schema_cache_dump = true
      RUBY

      app "development"

      assert ActiveRecord::ConnectionAdapters::SchemaReflection.use_schema_cache_dump
    end

    test "propagates use_schema_cache_dump=false to ActiveRecord::ConnectionAdapters::SchemaReflection" do
      add_to_config <<-RUBY
        config.active_record.use_schema_cache_dump = false
      RUBY

      app "development"

      assert_not ActiveRecord::ConnectionAdapters::SchemaReflection.use_schema_cache_dump
    end


    test "filter_parameters should be able to set via config.filter_parameters" do
      add_to_config <<-RUBY
        config.filter_parameters += [ :foo, 'bar', lambda { |key, value|
          value.reverse! if /baz/.match?(key)
        }]
      RUBY

      assert_nothing_raised do
        app "development"
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters in an initializer" do
      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/filter_parameters_logging.rb", <<-RUBY
        Rails.application.config.filter_parameters += [ :password, :foo, 'bar' ]
      RUBY

      app "development"

      assert_equal [:password, :foo, "bar"], Rails.application.env_config["action_dispatch.parameter_filter"]
    end

    test "filter_parameters is precompiled when config.precompile_filter_parameters is true" do
      filters = [/foo/, :bar, "baz.qux"]

      add_to_config <<~RUBY
        config.filter_parameters += #{filters.inspect}
        config.precompile_filter_parameters = true
      RUBY

      app "development"

      assert_equal ActiveSupport::ParameterFilter.precompile_filters(filters), Rails.application.env_config["action_dispatch.parameter_filter"]
    end

    test "filter_parameters is not precompiled when config.precompile_filter_parameters is false" do
      filters = [/foo/, :bar, "baz.qux"]

      add_to_config <<~RUBY
        config.filter_parameters += #{filters.inspect}
        config.precompile_filter_parameters = false
      RUBY

      app "development"

      assert_equal filters, Rails.application.env_config["action_dispatch.parameter_filter"]
    end

    test "filter_parameters reflects changes to config.filter_parameters after being precompiled" do
      add_to_config <<~RUBY
        config.filter_parameters += [/foo/, :bar]
        config.precompile_filter_parameters = true
      RUBY

      app "development"

      assert_not_empty Rails.application.env_config["action_dispatch.parameter_filter"]

      Rails.application.config.filter_parameters << "baz.qux"

      assert_includes Rails.application.env_config["action_dispatch.parameter_filter"], "baz.qux"
    end

    test "config.precompile_filter_parameters is true by default for new apps" do
      app "development"

      assert Rails.application.config.precompile_filter_parameters
    end

    test "config.precompile_filter_parameters is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_not Rails.application.config.precompile_filter_parameters
    end

    test "config.to_prepare is forwarded to ActionDispatch" do
      $prepared = false

      add_to_config <<-RUBY
        config.to_prepare do
          $prepared = true
        end
      RUBY

      assert_not $prepared

      app "development"

      get "/"
      assert $prepared
    end

    def assert_utf8
      assert_equal Encoding::UTF_8, Encoding.default_external
      assert_equal Encoding::UTF_8, Encoding.default_internal
    end

    test "skipping config.encoding still results in 'utf-8' as the default" do
      app "development"
      assert_utf8
    end

    test "config.encoding sets the default encoding" do
      add_to_config <<-RUBY
        config.encoding = "utf-8"
      RUBY

      app "development"
      assert_utf8
    end

    # Regression test for https://github.com/rails/rails/issues/49629.
    test "config.paths can be mutated after accessing auto/eager load paths" do
      app_dir "vendor/auto"
      app_dir "vendor/once"
      app_dir "vendor/eager"

      add_to_config <<~RUBY
        # Reading the collections is enough, no need to modify them.
        config.autoload_paths
        config.autoload_once_paths
        config.eager_load_paths

        config.paths.add("vendor/auto", autoload: true)
        config.paths.add("vendor/once", autoload_once: true)
        config.paths.add("vendor/eager", eager_load: true)
      RUBY

      app "development"

      assert_includes ActiveSupport::Dependencies.autoload_paths, "#{Rails.root}/vendor/auto"
      assert_includes ActiveSupport::Dependencies.autoload_once_paths, "#{Rails.root}/vendor/once"
      assert_includes ActiveSupport::Dependencies._eager_load_paths, "#{Rails.root}/vendor/eager"
    end

    test "config.paths.public sets Rails.public_path" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      app "development"
      assert_equal Pathname.new(app_path).join("somewhere"), Rails.public_path
    end

    test "In development mode, config.public_file_server.enabled is on by default" do
      restore_default_config

      with_rails_env "development" do
        app "development"
        assert app.config.public_file_server.enabled
      end
    end

    test "In test mode, config.public_file_server.enabled is on by default" do
      restore_default_config

      with_rails_env "test" do
        app "test"
        assert app.config.public_file_server.enabled
      end
    end

    test "In production mode, config.public_file_server.enabled is on by default" do
      restore_default_config

      with_rails_env "production" do
        app "production"
        assert app.config.public_file_server.enabled
      end
    end

    test "In production mode, STDOUT logging is the default" do
      restore_default_config

      with_rails_env "production" do
        app "production"
        assert ActiveSupport::Logger.logger_outputs_to?(app.config.logger, STDOUT)
      end
    end

    test "EtagWithFlash module doesn't break when the session store is disabled" do
      make_basic_app do |application|
        application.config.session_store :disabled
      end

      class ::OmgController < ActionController::Base
        def index
          stale?(weak_etag: "something")
          render plain: "else"
        end
      end

      get "/"

      assert_predicate last_response, :ok?
    end

    test "EtagWithFlash module doesn't break for API apps" do
      make_basic_app do |application|
        application.config.api_only = true
      end

      class ::OmgController < ActionController::Base
        def index
          stale?(weak_etag: "something")
          render plain: "else"
        end
      end

      get "/"

      assert_predicate last_response, :ok?
    end

    test "Use key_generator when secret_key_base is set" do
      make_basic_app do |application|
        application.config.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"
        application.config.session_store :disabled
      end

      class ::OmgController < ActionController::Base
        def index
          cookies.signed[:some_key] = "some_value"
          render plain: cookies[:some_key]
        end
      end

      get "/"

      secret = app.key_generator.generate_key("signed cookie")
      verifier = ActiveSupport::MessageVerifier.new(secret)
      assert_equal "some_value", verifier.verify(last_response.body)
    end

    test "application verifier can be used in the entire application" do
      make_basic_app do |application|
        application.config.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"
        application.config.session_store :disabled
      end

      message = app.message_verifier(:sensitive_value).generate("some_value")

      assert_equal "some_value", Rails.application.message_verifier(:sensitive_value).verify(message)

      secret = app.key_generator.generate_key("sensitive_value")
      verifier = ActiveSupport::MessageVerifier.new(secret)
      assert_equal "some_value", verifier.verify(message)
    end

    test "application will generate secret_key_base in tmp file if blank in development" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = nil
      RUBY

      # For test that works even if tmp dir does not exist.
      Dir.chdir(app_path) { FileUtils.remove_dir("tmp") }

      app "development"

      assert_not_nil app.secret_key_base
      assert File.exist?(app_path("tmp/local_secret.txt"))
    end

    test "application will generate secret_key_base in tmp file if blank in test" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = nil
      RUBY

      # For test that works even if tmp dir does not exist.
      Dir.chdir(app_path) { FileUtils.remove_dir("tmp") }

      app "test"

      assert_not_nil app.secret_key_base
      assert File.exist?(app_path("tmp/local_secret.txt"))
    end

    test "application will use ENV['SECRET_KEY_BASE'] if present in local env" do
      env_var_secret = "env_var_secret"
      ENV["SECRET_KEY_BASE"] = env_var_secret

      app "development"

      assert_equal env_var_secret, app.secret_key_base
    ensure
      ENV.delete "SECRET_KEY_BASE"
    end

    test "application will use secret_key_base from credentials if present in local env" do
      credentials_secret = "credentials_secret"
      add_to_config <<-RUBY
        Rails.application.credentials.secret_key_base = "#{credentials_secret}"
      RUBY

      app "development"

      assert_equal credentials_secret, app.secret_key_base
    end

    test "application will not generate secret_key_base in tmp file if blank in production" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.credentials.secret_key_base = nil
      RUBY

      assert_raises ArgumentError do
        app "production"
      end
    end

    test "raises when secret_key_base is blank" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.credentials.secret_key_base = nil
      RUBY

      error = assert_raise(ArgumentError) do
        app "production"
      end
      assert_match(/Missing `secret_key_base`./, error.message)
    end

    test "dont raise in production when dummy secret_key_base is used" do
      ENV["SECRET_KEY_BASE_DUMMY"] = "1"

      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.credentials.secret_key_base = nil
      RUBY

      assert_nothing_raised do
        app "production"
      end

      assert_not_nil app.secret_key_base
      assert File.exist?(app_path("tmp/local_secret.txt"))
    ensure
      ENV.delete "SECRET_KEY_BASE_DUMMY"
    end

    test "always use tmp file secret when dummy secret_key_base is used in production" do
      secret = "tmp_file_secret"
      ENV["SECRET_KEY_BASE_DUMMY"] = "1"
      ENV["SECRET_KEY_BASE"] = "env_secret"

      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.credentials.secret_key_base = "credentials_secret"
      RUBY

      app_dir("tmp")
      File.binwrite(app_path("tmp/local_secret.txt"), secret)

      app "production"

      assert_equal secret, app.secret_key_base
    ensure
      ENV.delete "SECRET_KEY_BASE_DUMMY"
      ENV.delete "SECRET_KEY_BASE"
    end

    test "raise when secret_key_base is not a type of string" do
      add_to_config <<-RUBY
        Rails.application.credentials.secret_key_base = 123
      RUBY

      assert_raise(ArgumentError) do
        app "production"
      end
    end

    test "don't output secret_key_base when calling inspect" do
      secret = "b3c631c314c0bbca50c1b2843150fe33"
      add_to_config <<-RUBY
        Rails.application.config.secret_key_base = "#{secret}"
      RUBY
      app "production"

      assert_no_match(/#{secret}/, Rails.application.config.inspect)
      assert_match(/\A#<Rails::Application::Configuration:0x[0-9a-f]+>\z/, Rails.application.config.inspect)
    end

    test "Rails.application.key_generator supports specifying a secret base" do
      app "production"

      key = app.key_generator.generate_key("salt")
      other_key = app.key_generator("other secret base").generate_key("salt")

      assert_not_equal key, other_key
      assert_equal key.length, other_key.length
    end

    test "application verifier can build different verifiers" do
      make_basic_app do |application|
        application.config.session_store :disabled
      end

      default_verifier = app.message_verifier(:sensitive_value)
      text_verifier = app.message_verifier(:text)

      message = text_verifier.generate("some_value")

      assert_equal "some_value", text_verifier.verify(message)
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        default_verifier.verify(message)
      end

      assert_equal default_verifier.object_id, app.message_verifier(:sensitive_value).object_id
      assert_not_equal default_verifier.object_id, text_verifier.object_id
    end

    test "Rails.application.message_verifiers.rotate supports :secret_key_base option" do
      old_secret_key_base = "old secret_key_base"

      add_to_config <<~RUBY
        config.before_initialize do |app|
          app.message_verifiers.rotate(secret_key_base: #{old_secret_key_base.inspect})
        end
      RUBY

      app "production"

      old_secret = app.key_generator(old_secret_key_base).generate_key("salt")
      old_message = ActiveSupport::MessageVerifier.new(old_secret).generate("old message")

      assert_equal "old message", app.message_verifiers["salt"].verify(old_message)
    end


    test "app.secret_key_base uses config.secret_key_base in development" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = "3b7cd727ee24e8444053437c36cc66c3"
      RUBY

      app "development"
      assert_equal "3b7cd727ee24e8444053437c36cc66c3", app.secret_key_base
    end

    test "app.secret_key_base uses config.secret_key_base in production" do
      remove_file "config/credentials.yml.enc"
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = "iaminallyoursecretkeybase"
      RUBY

      app "production"

      assert_equal "iaminallyoursecretkeybase", app.secret_key_base
    end

    test "require_master_key aborts app boot when missing key" do
      skip "can't run without fork" unless Process.respond_to?(:fork)

      remove_file "config/master.key"
      add_to_config "config.require_master_key = true"

      error = capture(:stderr) do
        Process.wait(Process.fork { app "development" })
      end

      assert_equal 1, $?.exitstatus
      assert_match(/Missing.*RAILS_MASTER_KEY/, error)
    end

    test "credentials does not raise error when require_master_key is false and master key does not exist" do
      remove_file "config/master.key"
      add_to_config "config.require_master_key = false"
      app "development"

      assert_not app.credentials.secret_key_base
    end

    test "protect from forgery is the default in a new app" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          render inline: "<%= csrf_meta_tags %>"
        end
      end

      get "/"
      assert_match(/csrf-param/, last_response.body)
    end

    test "default form builder specified as a string" do
      app_file "config/initializers/form_builder.rb", <<-RUBY
      class CustomFormBuilder < ActionView::Helpers::FormBuilder
        def text_field(attribute, *args)
          label(attribute) + super(attribute, *args)
        end
      end
      Rails.configuration.action_view.default_form_builder = "CustomFormBuilder"
      RUBY

      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def index
          render inline: "<%= begin; form_for(Post.new) {|f| f.text_field(:name)}; rescue => e; e.to_s; end %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      get "/posts"
      assert_match(/label/, last_response.body)
    end

    test "form_with can be configured with form_with_generates_ids" do
      app_file "config/initializers/form_builder.rb", <<-RUBY
      Rails.configuration.action_view.form_with_generates_ids = false
      RUBY

      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def index
          render inline: "<%= begin; form_with(model: Post.new) {|f| f.text_field(:name)}; rescue => e; e.to_s; end %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      get "/posts"

      assert_no_match(/id=('|")post_name('|")/, last_response.body)
    end

    test "form_with outputs ids by default" do
      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def index
          render inline: "<%= begin; form_with(model: Post.new) {|f| f.text_field(:name)}; rescue => e; e.to_s; end %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      get "/posts"

      assert_match(/id=('|")post_name('|")/, last_response.body)
    end

    test "form_with can be configured with form_with_generates_remote_forms" do
      app_file "config/initializers/form_builder.rb", <<-RUBY
      Rails.configuration.action_view.form_with_generates_remote_forms = true
      RUBY

      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def index
          render inline: "<%= begin; form_with(model: Post.new) {|f| f.text_field(:name)}; rescue => e; e.to_s; end %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      get "/posts"
      assert_match(/data-remote/, last_response.body)
    end

    test "form_with generates non remote forms by default" do
      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def index
          render inline: "<%= begin; form_with(model: Post.new) {|f| f.text_field(:name)}; rescue => e; e.to_s; end %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      get "/posts"
      assert_no_match(/data-remote/, last_response.body)
    end

    test "default method for update can be changed" do
      app_file "app/models/post.rb", <<-RUBY
      class Post
        include ActiveModel::Model
        def to_key; [1]; end
        def persisted?; true; end
      end
      RUBY

      token = "cf50faa3fe97702ca1ae"

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def show
          render inline: "<%= begin; form_for(Post.new) {}; rescue => e; e.to_s; end %>"
        end

        def update
          render plain: "update"
        end

        private

        def form_authenticity_token(**); token; end # stub the authenticity token
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      params = { authenticity_token: token }

      get "/posts/1"
      assert_match(/patch/, last_response.body)

      patch "/posts/1", params
      assert_match(/update/, last_response.body)

      patch "/posts/1", params
      assert_equal 200, last_response.status

      put "/posts/1", params
      assert_match(/update/, last_response.body)

      put "/posts/1", params
      assert_equal 200, last_response.status
    end

    test "request forgery token param can be changed" do
      make_basic_app do |application|
        application.config.action_controller.request_forgery_protection_token = "_xsrf_token_here"
      end

      class ::OmgController < ActionController::Base
        def index
          render inline: "<%= csrf_meta_tags %>"
        end
      end

      get "/"
      assert_match "_xsrf_token_here", last_response.body
    end

    test "sets ActionDispatch.test_app" do
      make_basic_app
      assert_equal Rails.application, ActionDispatch.test_app
    end

    test "sets ActionDispatch::Response.default_charset" do
      make_basic_app do |application|
        application.config.action_dispatch.default_charset = "utf-16"
      end

      assert_equal "utf-16", ActionDispatch::Response.default_charset
    end

    test "registers interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.interceptors = MyMailInterceptor
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor], ::Mail.class_variable_get(:@@delivery_interceptors)
    end

    test "registers multiple interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.interceptors = [MyMailInterceptor, "MyOtherMailInterceptor"]
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor, ::MyOtherMailInterceptor], ::Mail.class_variable_get(:@@delivery_interceptors)
    end

    test "registers preview interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.preview_interceptors = MyPreviewMailInterceptor
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [ActionMailer::InlinePreviewInterceptor, ::MyPreviewMailInterceptor], ActionMailer::Base.preview_interceptors
    end

    test "registers multiple preview interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.preview_interceptors = [MyPreviewMailInterceptor, "MyOtherPreviewMailInterceptor"]
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [ActionMailer::InlinePreviewInterceptor, MyPreviewMailInterceptor, MyOtherPreviewMailInterceptor], ActionMailer::Base.preview_interceptors
    end

    test "default preview interceptor can be removed" do
      app_file "config/initializers/preview_interceptors.rb", <<-RUBY
        ActionMailer::Base.preview_interceptors.delete(ActionMailer::InlinePreviewInterceptor)
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [], ActionMailer::Base.preview_interceptors
    end

    test "registers observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = MyMailObserver
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailObserver], ::Mail.class_variable_get(:@@delivery_notification_observers)
    end

    test "registers multiple observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = [MyMailObserver, "MyOtherMailObserver"]
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailObserver, ::MyOtherMailObserver], ::Mail.class_variable_get(:@@delivery_notification_observers)
    end

    test "allows setting the queue name for the ActionMailer::MailDeliveryJob" do
      add_to_config <<-RUBY
        config.action_mailer.deliver_later_queue_name = 'test_default'
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal "test_default", ActionMailer::Base.deliver_later_queue_name
    end

    test "ActionMailer::DeliveryJob queue name is :mailers without the Rails defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal :mailers, ActionMailer::Base.deliver_later_queue_name
    end

    test "ActionMailer::DeliveryJob queue name is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_nil ActionMailer::Base.deliver_later_queue_name
    end

    test "valid timezone is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.time_zone = "Wellington"
      RUBY

      app "development"

      assert_equal "Wellington", Rails.application.config.time_zone
    end

    test "raises when an invalid timezone is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.time_zone = "That big hill over yonder hill"
      RUBY

      assert_raise(ArgumentError) do
        app "development"
      end
    end

    test "valid beginning of week is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.beginning_of_week = :wednesday
      RUBY

      app "development"

      assert_equal :wednesday, Rails.application.config.beginning_of_week
    end

    test "raises when an invalid beginning of week is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.beginning_of_week = :invalid
      RUBY

      assert_raise(ArgumentError) do
        app "development"
      end
    end

    test "autoloaders" do
      app "development"

      assert_predicate Rails.autoloaders, :zeitwerk_enabled?
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.main
      assert_equal "rails.main", Rails.autoloaders.main.tag
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.once
      assert_equal "rails.once", Rails.autoloaders.once.tag
      assert_equal [Rails.autoloaders.main, Rails.autoloaders.once], Rails.autoloaders.to_a
      assert_equal Rails::Autoloaders::Inflector, Rails.autoloaders.main.inflector
      assert_equal Rails::Autoloaders::Inflector, Rails.autoloaders.once.inflector
    end

    test "config.action_view.cache_template_loading with config.enable_reloading default" do
      add_to_config "config.enable_reloading = false"

      app "development"
      require "action_view/base"

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading without config.enable_reloading default" do
      add_to_config "config.enable_reloading = true"

      app "development"
      require "action_view/base"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = false" do
      add_to_config <<-RUBY
        config.enable_reloading = false
        config.action_view.cache_template_loading = false
      RUBY

      app "development"
      require "action_view/base"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = true" do
      add_to_config <<-RUBY
        config.enable_reloading = true
        config.action_view.cache_template_loading = true
      RUBY

      app "development"
      require "action_view/base"

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading with config.enable_reloading in an environment" do
      restore_default_config
      add_to_env_config "development", "config.enable_reloading = true"

      # These requires are to emulate an engine loading Action View before the application
      require "action_view"
      require "action_view/railtie"
      require "action_view/base"

      app "development"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "ActionController::Base::renderer uses Rails.application.default_url_options and config.force_ssl" do
      add_to_config <<~RUBY
        config.force_ssl = true

        Rails.application.default_url_options = {
          host: "foo.example.com",
          port: 9001,
          script_name: "/bar",
        }

        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      posts_url = ApplicationController.renderer.render(inline: "<%= posts_url %>")
      assert_equal "https://foo.example.com:9001/bar/posts", posts_url
    end

    test "ActionController::Base.raise_on_open_redirects is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'
      app "development"

      assert_equal false, ActionController::Base.raise_on_open_redirects
    end

    test "ActionController::Base.raise_on_open_redirects can be configured in the new framework defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_2.rb", <<-RUBY
        Rails.application.config.action_controller.raise_on_open_redirects = true
      RUBY

      app "development"

      assert_equal true, ActionController::Base.raise_on_open_redirects
    end

    test "ActionController::Base.action_on_open_redirect is :raise by default for new apps" do
      app "development"

      assert_equal :raise, ActionController::Base.action_on_open_redirect
    end

    test "ActionController::Base.action_on_open_redirect is :log when raise_on_open_redirects is false" do
      add_to_config "config.action_controller.raise_on_open_redirects = false"
      app "development"

      assert_equal :log, ActionController::Base.action_on_open_redirect
    end

    test "config.action_dispatch.show_exceptions is sent in env" do
      make_basic_app do |application|
        application.config.action_dispatch.show_exceptions = :all
      end

      class ::OmgController < ActionController::Base
        def index
          render plain: request.env["action_dispatch.show_exceptions"]
        end
      end

      get "/"
      assert_equal "all", last_response.body
    end

    test "config.action_controller.wrap_parameters is set in ActionController::Base" do
      app_file "config/initializers/wrap_parameters.rb", <<-RUBY
        ActionController::Base.wrap_parameters format: [:json]
      RUBY

      app_file "app/models/post.rb", <<-RUBY
      class Post
        def self.attribute_names
          %w(title)
        end
      end
      RUBY

      app_file "app/controllers/application_controller.rb", <<-RUBY
      class ApplicationController < ActionController::Base
        protect_from_forgery with: :reset_session # as we are testing API here
      end
      RUBY

      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ApplicationController
        def create
          render plain: params[:post].inspect
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app "development"

      post "/posts.json", '{ "title": "foo", "name": "bar" }', "CONTENT_TYPE" => "application/json"
      assert_equal "#<ActionController::Parameters #{{ "title" => "foo" }} permitted: false>", last_response.body
    end

    test "config.action_controller.permit_all_parameters = true" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ActionController::Base
        def create
          render plain: params[:post].permitted? ? "permitted" : "forbidden"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.permit_all_parameters = true
      RUBY

      app "development"

      post "/posts", post: { "title" => "zomg" }
      assert_equal "permitted", last_response.body
    end

    test "config.action_controller.action_on_unpermitted_parameters = :raise" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ActionController::Base
        def create
          render plain: params.permit(post: [:name])
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters

      post "/posts", post: { "title" => "zomg" }
      assert_match "We're sorry, but something went wrong", last_response.body
    end

    test "config.action_controller.action_on_unpermitted_parameters = :raise is ignored with expect" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ActionController::Base
        def create
          render plain: params.expect(post: [:name])
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters

      post "/posts", post: { "title" => "zomg" }
      assert_match "The server cannot process the request due to a client error", last_response.body
    end

    test "config.action_controller.always_permitted_parameters are: controller, action by default" do
      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal %w(controller action), ActionController::Parameters.always_permitted_parameters
    end

    test "config.action_controller.always_permitted_parameters = ['controller', 'action', 'format']" do
      add_to_config <<-RUBY
        config.action_controller.always_permitted_parameters = %w( controller action format )
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal %w( controller action format ), ActionController::Parameters.always_permitted_parameters
    end

    test "config.action_controller.always_permitted_parameters = ['controller','action','format'] does not raise exception" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ActionController::Base
        def create
          render plain: params.permit(post: [:title])
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.always_permitted_parameters = %w( controller action format )
        config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters

      post "/posts", post: { "title" => "zomg" }, format: "json"
      assert_equal 200, last_response.status
    end

    test "config.action_controller.action_on_unpermitted_parameters is :log by default in development" do
      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :log, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_controller.action_on_unpermitted_parameters is :log by default in test" do
      app "test"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :log, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_controller.action_on_unpermitted_parameters is false by default in production" do
      app "production"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal false, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_controller.default_protect_from_forgery is true by default" do
      app "development"

      assert_includes ActionController::Base.__callbacks[:process_action].map(&:filter), :verify_request_for_forgery_protection
    end

    test "config.action_controller.default_protect_from_forgery_with is :exception by default in 8.2" do
      app "development"

      require "action_controller/base"
      assert_equal :exception, ActionController::Base.default_protect_from_forgery_with
    end

    test "config.action_controller.default_protect_from_forgery_with can be configured" do
      add_to_config <<-RUBY
        config.action_controller.default_protect_from_forgery_with = :reset_session
      RUBY

      app "development"

      require "action_controller/base"
      assert_equal :reset_session, ActionController::Base.default_protect_from_forgery_with
    end

    test "config.action_controller.permit_all_parameters can be configured in an initializer" do
      app_file "config/initializers/permit_all_parameters.rb", <<-RUBY
        Rails.application.config.action_controller.permit_all_parameters = true
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal true, ActionController::Parameters.permit_all_parameters
    end

    test "config.action_controller.always_permitted_parameters can be configured in an initializer" do
      app_file "config/initializers/always_permitted_parameters.rb", <<-RUBY
        Rails.application.config.action_controller.always_permitted_parameters = []
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal [], ActionController::Parameters.always_permitted_parameters
    end

    test "config.action_controller.action_on_unpermitted_parameters can be configured in an initializer" do
      app_file "config/initializers/action_on_unpermitted_parameters.rb", <<-RUBY
        Rails.application.config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      app "development"

      require "action_controller/base"
      require "action_controller/api"

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_dispatch.ignore_accept_header" do
      make_basic_app do |application|
        application.config.action_dispatch.ignore_accept_header = true
      end

      class ::OmgController < ActionController::Base
        def index
          respond_to do |format|
            format.html { render plain: "HTML" }
            format.xml { render plain: "XML" }
          end
        end
      end

      get "/", {}, { "HTTP_ACCEPT" => "application/xml" }
      assert_equal "HTML", last_response.body

      get "/", { format: :xml }, { "HTTP_ACCEPT" => "application/xml" }
      assert_equal "XML", last_response.body
    end

    test "Rails.application#env_config exists and includes some existing parameters" do
      make_basic_app

      assert_equal app.env_config["action_dispatch.parameter_filter"],  app.config.filter_parameters
      assert_equal app.env_config["action_dispatch.show_exceptions"],   app.config.action_dispatch.show_exceptions
      assert_equal app.env_config["action_dispatch.logger"],            Rails.logger
      assert_equal app.env_config["action_dispatch.backtrace_cleaner"], Rails.backtrace_cleaner
      assert_equal app.env_config["action_dispatch.key_generator"],     Rails.application.key_generator
    end

    test "config.colorize_logging default is true" do
      make_basic_app
      assert app.config.colorize_logging
    end

    test "config.session_store with custom custom stores search for it inside the ActionDispatch::Session namespace" do
      assert_nothing_raised do
        make_basic_app do |application|
          ActionDispatch::Session::MyCustomStore = Class.new(ActionDispatch::Session::CookieStore)
          application.config.session_store :my_custom_store
        end
      end
    ensure
      ActionDispatch::Session.send :remove_const, :MyCustomStore
    end

    test "config.session_store with unknown store raises helpful error" do
      e = assert_raise RuntimeError do
        make_basic_app do |application|
          application.config.session_store :unknown_store
        end
      end

      assert_match(/Unable to resolve session store :unknown_store/, e.message)
    end

    test "default session store initializer does not overwrite the user defined session store even if it is disabled" do
      make_basic_app do |application|
        application.config.session_store :disabled
      end

      assert_nil app.config.session_store
    end

    test "default session store initializer sets session store to cookie store" do
      session_options = { key: "_myapp_session", cookie_only: true }
      make_basic_app

      assert_equal ActionDispatch::Session::CookieStore, app.config.session_store
      session_options.each do |key, value|
        assert_equal value, app.config.session_options[key]
      end
    end

    test "config.log_level defaults to debug in development" do
      restore_default_config
      app "development"

      assert_equal Logger::DEBUG, Rails.logger.level
    end

    test "config.log_level default to info in production" do
      restore_default_config
      app "production"

      assert_equal Logger::INFO, Rails.logger.level
    end

    test "config.log_level can be overwritten by ENV['RAILS_LOG_LEVEL'] in production" do
      restore_default_config

      switch_env "RAILS_LOG_LEVEL", "debug" do
        app "production"
        assert_equal Logger::DEBUG, Rails.logger.level
      end
    end

    test "config.log_level with custom logger" do
      make_basic_app do |application|
        application.config.logger = Logger.new(STDOUT)
        application.config.log_level = :debug
      end
      assert_equal Logger::DEBUG, Rails.logger.level
    end

    test "config.log_level does not override the level of the broadcast with the default value" do
      add_to_config <<-RUBY
        stdout = Logger.new(STDOUT, level: Logger::INFO)
        stderr = Logger.new(STDERR, level: Logger::ERROR)
        config.logger = ActiveSupport::BroadcastLogger.new(stdout, stderr)
      RUBY

      app "development"

      assert_equal([Logger::INFO, Logger::ERROR], Rails.logger.broadcasts.map(&:level))
    end

    test "config.log_level overrides the level of the broadcast when a custom value is set" do
      add_to_config <<-RUBY
        stdout = Logger.new(STDOUT)
        stderr = Logger.new(STDERR)
        config.logger = ActiveSupport::BroadcastLogger.new(stdout, stderr)
        config.log_level = :warn
      RUBY

      app "development"

      assert_equal([Logger::WARN, Logger::WARN], Rails.logger.broadcasts.map(&:level))
    end

    test "config.logger when logger is already a Broadcast Logger" do
      logger = ActiveSupport::BroadcastLogger.new

      make_basic_app do |application|
        application.config.logger = logger
      end
      assert_same(logger, Rails.logger)
    end

    test "config.logger when logger is not a Broadcast Logger" do
      logger = Logger.new(STDOUT)

      make_basic_app do |application|
        application.config.logger = logger
      end

      assert_instance_of(ActiveSupport::BroadcastLogger, Rails.logger)
      assert_includes(Rails.logger.broadcasts, logger)
    end

    test "respond_to? accepts include_private" do
      make_basic_app

      assert_not_respond_to Rails.configuration, :method_missing
      assert Rails.configuration.respond_to?(:method_missing, true)
    end

    test "config.active_record.dump_schema_after_migration is false on production" do
      restore_default_config
      app "production"

      assert_not ActiveRecord.dump_schema_after_migration
    end

    test "config.active_record.dump_schema_after_migration is true by default in development" do
      app "development"

      assert ActiveRecord.dump_schema_after_migration
    end

    test "config.active_record.verbose_query_logs is false by default in development" do
      app "development"

      assert_not ActiveRecord.verbose_query_logs
    end

    test "config.active_record.use_yaml_unsafe_load is false by default" do
      app "production"
      assert_not ActiveRecord.use_yaml_unsafe_load
    end

    test "config.active_record.use_yaml_unsafe_load can be configured" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/use_yaml_unsafe_load.rb", <<-RUBY
        Rails.application.config.active_record.use_yaml_unsafe_load = true
      RUBY

      app "production"
      assert ActiveRecord.use_yaml_unsafe_load
    end

    test "config.active_record.raise_int_wider_than_64bit is true by default" do
      app "production"
      assert ActiveRecord.raise_int_wider_than_64bit
    end

    test "config.active_record.raise_int_wider_than_64bit can be configured" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/dont_raise.rb", <<-RUBY
        Rails.application.config.active_record.raise_int_wider_than_64bit = false
      RUBY

      app "production"
      assert_not ActiveRecord.raise_int_wider_than_64bit
    end


    test "config.active_record.yaml_column_permitted_classes is [Symbol] by default" do
      app "production"
      assert_equal([Symbol], ActiveRecord.yaml_column_permitted_classes)
    end

    test "config.active_record.yaml_column_permitted_classes can be configured" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/yaml_permitted_classes.rb", <<-RUBY
        Rails.application.config.active_record.yaml_column_permitted_classes = [Symbol, Time]
      RUBY

      app "production"
      assert_equal([Symbol, Time], ActiveRecord.yaml_column_permitted_classes)
    end

    test "config.annotations wrapping SourceAnnotationExtractor::Annotation class" do
      make_basic_app do |application|
        application.config.annotations.register_extensions("coffee") do |tag|
          /#\s*(#{tag}):?\s*(.*)$/
        end
      end

      assert_not_nil Rails::SourceAnnotationExtractor::Annotation.extensions[/\.(coffee)$/]
    end

    test "config.default_log_file returns a File instance" do
      app "development"

      assert_instance_of File, app.config.default_log_file
      assert_equal Rails.application.config.paths["log"].first, app.config.default_log_file.path
    end

    test "config.log_file_size returns a 100MB size number in development" do
      app "development"

      assert_equal 100.megabytes, app.config.log_file_size
    end

    test "config.log_file_size returns a 100MB size number in test" do
      app "test"

      assert_equal 100.megabytes, app.config.log_file_size
    end

    test "config.log_file_size returns no limit in production" do
      app "production"

      assert_nil app.config.log_file_size
    end

    test "rake_tasks block works at instance level" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.ran_block = false

          rake_tasks do
            config.ran_block = true
          end
        end
      RUBY

      app "development"
      assert_not Rails.configuration.ran_block

      require "rake"
      require "rake/testtask"
      require "rdoc/task"

      Rails.application.load_tasks
      assert Rails.configuration.ran_block
    end

    test "generators block works at instance level" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.ran_block = false

          generators do
            config.ran_block = true
          end
        end
      RUBY

      app "development"
      assert_not Rails.configuration.ran_block

      Rails.application.load_generators
      assert Rails.configuration.ran_block
    end

    test "console block works at instance level" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.ran_block = false

          console do
            config.ran_block = true
          end
        end
      RUBY

      app "development"
      assert_not Rails.configuration.ran_block

      Rails.application.load_console
      assert Rails.configuration.ran_block
    end

    test "runner block works at instance level" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.ran_block = false

          runner do
            config.ran_block = true
          end
        end
      RUBY

      app "development"
      assert_not Rails.configuration.ran_block

      Rails.application.load_runner
      assert Rails.configuration.ran_block
    end

    test "loading the first existing database configuration available" do
      app_file "config/environments/development.rb", <<-RUBY

      Rails.application.configure do
        config.paths.add 'config/database', with: 'config/nonexistent.yml'
        config.paths['config/database'] << 'config/database.yml'
        end
      RUBY

      app "development"

      assert_kind_of Hash, Rails.application.config.database_configuration
    end

    test "autoload paths do not include asset paths" do
      app "development"
      ActiveSupport::Dependencies.autoload_paths.each do |path|
        assert_not_operator path, :end_with?, "app/assets"
        assert_not_operator path, :end_with?, "app/javascript"
      end
    end

    test "autoload paths do not include custom config.javascript_paths" do
      # The config.javascript_path assignment has to be in place before
      # config.paths is accessed, since their compilation uses the value.
      add_to_top_of_config "config.javascript_path = 'webpack'"
      app_dir("app/webpack")

      app "development"

      ActiveSupport::Dependencies.autoload_paths.each do |path|
        assert_not_operator path, :end_with?, "app/assets"
        assert_not_operator path, :end_with?, "app/webpack"
      end
    end

    test "autoload paths are not added to $LOAD_PATH if opted-in" do
      add_to_config "config.add_autoload_paths_to_load_path = true"
      app "development"

      # Action Mailer modifies AS::Dependencies.autoload_paths in-place.
      autoload_paths = ActiveSupport::Dependencies.autoload_paths
      autoload_paths_from_app_and_engines = autoload_paths.reject do |path|
        path.end_with?("mailers/previews")
      end
      assert_equal true, Rails.configuration.add_autoload_paths_to_load_path
      assert_empty autoload_paths_from_app_and_engines - $LOAD_PATH

      # Precondition, ensure we are testing something next.
      assert_not_empty Rails.configuration.paths.load_paths
      assert_empty Rails.configuration.paths.load_paths - $LOAD_PATH
    end

    test "autoload paths are not added to $LOAD_PATH by default, except for lib" do
      app "development"

      assert_equal ["#{app_path}/lib"], ActiveSupport::Dependencies.autoload_paths & $LOAD_PATH

      # Precondition, ensure we are testing something next.
      assert_not_empty Rails.configuration.paths.load_paths
      assert_empty Rails.configuration.paths.load_paths - $LOAD_PATH
    end

    test "lib is added to $LOAD_PATH regardless of config.add_autoload_paths_to_load_path" do
      # Like Rails::Application.add_lib_to_load_path! does.
      lib = File.join(app_path, "lib")

      add_to_config "config.autoload_paths << '#{lib}'"

      app "development"

      assert_not Rails.configuration.add_autoload_paths_to_load_path # precondition
      assert_includes $LOAD_PATH, lib
    end

    test "config.autoload_lib(...) is generated by default" do
      app_file "lib/x.rb", "X = true"
      app_file "lib/m/x.rb", "M::X = true"
      app_file "lib/assets/x.rb", "Assets::X = true"
      app_file "lib/tasks/x.rb", "Tasks::X = true"

      app "development"

      assert_includes Rails.application.config.autoload_paths, "#{app_path}/lib"
      assert_includes Rails.application.config.eager_load_paths, "#{app_path}/lib"

      assert X
      assert M::X
      assert_raises(NameError) { Assets }
      assert_raises(NameError) { Tasks }
    end

    test "autoload paths can be set in the config file of the environment" do
      app_dir "custom_autoload_path"
      app_dir "custom_autoload_once_path"
      app_dir "custom_eager_load_path"

      restore_default_config
      add_to_env_config "development", <<-RUBY
        config.autoload_paths      << "#{app_path}/custom_autoload_path"
        config.autoload_once_paths << "#{app_path}/custom_autoload_once_path"
        config.eager_load_paths    << "#{app_path}/custom_eager_load_path"
      RUBY

      app "development"

      Rails.application.config.tap do |config|
        assert_includes config.autoload_paths, "#{app_path}/custom_autoload_path"
        assert_includes config.autoload_once_paths, "#{app_path}/custom_autoload_once_path"
        assert_includes config.eager_load_paths, "#{app_path}/custom_eager_load_path"
      end
    end

    [%w(autoload_lib autoload_paths), %w(autoload_lib_once autoload_once_paths)].each do |method_name, paths|
      test "config.#{method_name} adds lib to the expected paths (array ignore)" do
        app_file "lib/x.rb", "X = true"
        app_file "lib/tasks/x.rb", "Tasks::X = true"
        app_file "lib/generators/x.rb", "Generators::X = true"

        remove_from_config "config\\.#{method_name}.*"
        add_to_config "config.#{method_name}(ignore: %w(tasks generators))"

        app "development"

        Rails.application.config.tap do |config|
          assert_includes config.send(paths), "#{app_path}/lib"
          assert_includes config.eager_load_paths, "#{app_path}/lib"
        end

        assert X
        assert_raises(NameError) { Tasks }
        assert_raises(NameError) { Generators }
      end

      test "config.#{method_name} adds lib to the expected paths (empty array ignore)" do
        app_file "lib/x.rb", "X = true"
        app_file "lib/tasks/x.rb", "Tasks::X = true"

        remove_from_config "config\\.#{method_name}.*"
        add_to_config "config.#{method_name}(ignore: [])"

        app "development"

        Rails.application.config.tap do |config|
          assert_includes config.send(paths), "#{app_path}/lib"
          assert_includes config.eager_load_paths, "#{app_path}/lib"
        end

        assert X
        assert Tasks::X
      end

      test "config.#{method_name} adds lib to the expected paths (scalar ignore)" do
        app_file "lib/x.rb", "X = true"
        app_file "lib/tasks/x.rb", "Tasks::X = true"

        remove_from_config "config\\.#{method_name}.*"
        add_to_config "config.#{method_name}(ignore: 'tasks')"

        app "development"

        Rails.application.config.tap do |config|
          assert_includes config.send(paths), "#{app_path}/lib"
          assert_includes config.eager_load_paths, "#{app_path}/lib"
        end

        assert X
        assert_raises(NameError) { Tasks }
      end

      test "config.#{method_name} adds lib to the expected paths (nil ignore)" do
        app_file "lib/x.rb", "X = true"
        app_file "lib/tasks/x.rb", "Tasks::X = true"

        remove_from_config "config\\.#{method_name}.*"
        add_to_config "config.#{method_name}(ignore: nil)"

        app "development"

        Rails.application.config.tap do |config|
          assert_includes config.send(paths), "#{app_path}/lib"
          assert_includes config.eager_load_paths, "#{app_path}/lib"
        end

        assert X
        assert Tasks::X
      end
    end

    test "load_database_yaml returns blank hash if configuration file is blank" do
      app_file "config/database.yml", ""
      app "development"
      assert_equal({}, Rails.application.config.load_database_yaml)
    end

    test "load_database_yaml returns blank hash if no database configuration is found" do
      remove_file "config/database.yml"
      app "development"
      assert_equal({}, Rails.application.config.load_database_yaml)
    end

    test "setup_initial_database_yaml does not print a warning" do
      app_file "config/database.yml", <<-YAML
        <%= Rails.env %>:
          username: bobby
          adapter: sqlite3
          database: 'dev_db'
      YAML
      app "development"

      assert_silent do
        ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml
      end
    end

    test "raises with proper error message if no database configuration found" do
      FileUtils.rm("#{app_path}/config/database.yml")
      err = assert_raises RuntimeError do
        app "development"
        Rails.application.config.database_configuration
      end
      assert_match "config/database", err.message
    end

    test "loads database.yml using shared keys" do
      app_file "config/database.yml", <<-YAML
        shared:
          username: bobby
          adapter: sqlite3

        development:
          database: 'dev_db'
      YAML

      app "development"

      ar_config = Rails.application.config.database_configuration
      assert_equal "sqlite3", ar_config["development"]["adapter"]
      assert_equal "bobby",   ar_config["development"]["username"]
      assert_equal "dev_db",  ar_config["development"]["database"]
    end

    test "loads database.yml using shared keys for undefined environments" do
      app_file "config/database.yml", <<-YAML
        shared:
          username: bobby
          adapter: sqlite3
          database: 'dev_db'
      YAML

      app "development"

      ar_config = Rails.application.config.database_configuration
      assert_equal "sqlite3", ar_config["development"]["adapter"]
      assert_equal "bobby",   ar_config["development"]["username"]
      assert_equal "dev_db",  ar_config["development"]["database"]
    end

    test "loads database.yml using shared keys with a 3-tier config" do
      app_file "config/database.yml", <<-YAML
        shared:
          username: bobby
          adapter: sqlite3

        development:
          primary:
            database: 'dev_db'
      YAML

      app "development"

      ar_config = Rails.application.config.database_configuration
      assert_equal "sqlite3", ar_config["development"]["primary"]["adapter"]
      assert_equal "bobby",   ar_config["development"]["primary"]["username"]
      assert_equal "dev_db",  ar_config["development"]["primary"]["database"]
    end

    test "loads database.yml using 3-tier shared keys with a 3-tier config" do
      app_file "config/database.yml", <<-YAML
        shared:
          one:
            migrations_path: "db/one"
          two:
            migrations_path: "db/two"

        development:
          one:
            adapter: sqlite3
          two:
            adapter: sqlite3
      YAML

      app "development"

      ar_config = Rails.configuration.database_configuration
      assert_equal "db/one", ar_config["development"]["one"]["migrations_path"]
      assert_equal "db/two", ar_config["development"]["two"]["migrations_path"]
    end

    test "config.action_mailer.show_previews defaults to true in development" do
      app "development"

      assert Rails.application.config.action_mailer.show_previews
    end

    test "config.action_mailer.show_previews defaults to false in production" do
      app "production"

      assert_equal false, Rails.application.config.action_mailer.show_previews
    end

    test "config.action_mailer.show_previews can be set in the configuration file" do
      add_to_config <<-RUBY
        config.action_mailer.show_previews = true
      RUBY

      app "production"

      assert_equal true, Rails.application.config.action_mailer.show_previews
    end

    test "config_for loads custom configuration from YAML accessible as symbol or string" do
      set_custom_config <<~RUBY
        development:
          foo: "bar"
      RUBY

      app "development"

      assert_equal "bar", Rails.application.config.my_custom_config[:foo]
      assert_equal "bar", Rails.application.config.my_custom_config["foo"]
    end

    test "config_for loads nested custom configuration from YAML as symbol keys" do
      set_custom_config <<~RUBY
        development:
          foo:
            bar:
              baz: 1
      RUBY

      app "development"

      assert_equal 1, Rails.application.config.my_custom_config[:foo][:bar][:baz]
    end

    test "config_for makes all hash methods available" do
      set_custom_config <<~RUBY
        development:
          foo: 0
          bar:
            baz: 1
      RUBY

      app "development"

      actual = Rails.application.config.my_custom_config
      assert_equal({ foo: 0, bar: { baz: 1 } }, actual)
      assert_equal([ :foo, :bar ], actual.keys)
      assert_equal([ 0, baz: 1], actual.values)
      assert_equal({ foo: 0, bar: { baz: 1 } }, actual.to_h)
      assert_equal(0, actual[:foo])
      assert_equal({ baz: 1 }, actual[:bar])
    end

    test "config_for does not assume config is a hash" do
      set_custom_config <<~RUBY
        development:
          - foo
          - bar
      RUBY

      app "development"

      assert_equal %w( foo bar ), Rails.application.config.my_custom_config
    end

    test "config_for works with only a shared root array" do
      set_custom_config <<~RUBY
        shared:
          - foo
          - bar
      RUBY

      app "development"

      assert_equal %w( foo bar ), Rails.application.config.my_custom_config
    end

    test "config_for returns only the env array when shared is an array" do
      set_custom_config <<~RUBY
        development:
          - baz
        shared:
          - foo
          - bar
      RUBY

      app "development"

      assert_equal %w( baz ), Rails.application.config.my_custom_config
    end

    test "config_for uses the Pathname object if it is provided" do
      set_custom_config <<~RUBY, "Pathname.new(Rails.root.join('config/custom.yml'))"
        development:
          key: 'custom key'
      RUBY

      app "development"

      assert_equal "custom key", Rails.application.config.my_custom_config[:key]
    end

    test "config_for raises an exception if the file does not exist" do
      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      exception = assert_raises(RuntimeError) do
        app "development"
      end

      assert_equal "Could not load configuration. No such file - #{app_path}/config/custom.yml", exception.message
    end

    test "config_for without the environment configured returns nil" do
      set_custom_config <<~RUBY
        test:
          key: 'custom key'
      RUBY

      app "development"

      assert_nil Rails.application.config.my_custom_config
    end

    test "config_for shared config is overridden" do
      set_custom_config <<~RUBY
        shared:
          foo: :from_shared
        test:
          foo: :from_env
      RUBY

      app "test"

      assert_equal :from_env, Rails.application.config.my_custom_config[:foo]
    end

    test "config_for shared config is returned when environment is missing" do
      set_custom_config <<~RUBY
        shared:
          foo: :from_shared
        test:
          foo: :from_env
      RUBY

      app "development"

      assert_equal :from_shared, Rails.application.config.my_custom_config[:foo]
    end

    test "config_for merges shared configuration deeply" do
      set_custom_config <<~RUBY
        shared:
          foo:
            bar:
              baz: 1
        development:
          foo:
            bar:
              qux: 2
      RUBY

      app "development"

      assert_equal({ baz: 1, qux: 2 }, Rails.application.config.my_custom_config[:foo][:bar])
    end

    test "config_for with empty file returns nil" do
      set_custom_config ""

      app "development"

      assert_nil Rails.application.config.my_custom_config
    end

    test "config_for containing ERB tags should evaluate" do
      set_custom_config <<~YAML
        development:
          key: <%= 'custom key' %>
      YAML

      app "development"

      assert_equal "custom key", Rails.application.config.my_custom_config[:key]
    end

    test "config_for with syntax error show a more descriptive exception" do
      set_custom_config <<~RUBY
        development:
          key: foo:
      RUBY

      error = assert_raises RuntimeError do
        app "development"
      end
      assert_match "YAML syntax error occurred while parsing", error.message
    end

    test "config_for allows overriding the environment" do
      set_custom_config <<~RUBY, "'custom', env: 'production'"
        test:
          key: 'walrus'
        production:
          key: 'unicorn'
      RUBY

      require "#{app_path}/config/environment"

      assert_equal "unicorn", Rails.application.config.my_custom_config[:key]
    end

    test "config_for handles YAML patches (like safe_yaml) that disable the symbolize_names option" do
      app_file "config/custom.yml", <<~RUBY
        development:
          key: value
      RUBY

      app "development"

      YAML.stub :load, { "development" => { "key" => "value" } } do
        assert_equal({ key: "value" }, Rails.application.config_for(:custom))
      end
    end

    test "config_for returns a ActiveSupport::OrderedOptions" do
      app_file "config/custom.yml", <<~YAML
        shared:
          some_key: default

        development:
          some_key: value

        test:
      YAML

      app "development"

      config = Rails.application.config_for(:custom)
      assert_instance_of ActiveSupport::OrderedOptions, config
      assert_equal "value", config.some_key

      config = Rails.application.config_for(:custom, env: :test)
      assert_instance_of ActiveSupport::OrderedOptions, config
      assert_equal "default", config.some_key
    end

    test "api_only is false by default" do
      app "development"
      assert_not Rails.application.config.api_only
    end

    test "api_only generator config is set when api_only is set" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY
      app "development"

      Rails.application.load_generators
      assert Rails.configuration.api_only
    end

    test "debug_exception_response_format is :api by default if api_only is enabled" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY
      app "development"

      assert_equal :api, Rails.configuration.debug_exception_response_format
    end

    test "debug_exception_response_format can be overridden" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY

      app_file "config/environments/development.rb", <<-RUBY
      Rails.application.configure do
        config.debug_exception_response_format = :default
      end
      RUBY

      app "development"

      assert_equal :default, Rails.configuration.debug_exception_response_format
    end

    test "debug_exception_log_level is :fatal by default for upgraded apps" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          render plain: request.env["action_dispatch.debug_exception_log_level"]
        end
      end

      get "/"

      assert_equal "4", last_response.body
    end

    test "debug_exception_log_level is :error for new apps" do
      make_basic_app do |app|
        app.config.load_defaults "7.1"
      end

      class ::OmgController < ActionController::Base
        def index
          render plain: request.env["action_dispatch.debug_exception_log_level"]
        end
      end

      get "/"

      assert_equal "3", last_response.body
    end

    test "ActiveRecord::Base.has_many_inversing is true by default for new apps" do
      app "development"

      assert_equal true, ActiveRecord::Base.has_many_inversing
    end

    test "ActiveRecord::Base.has_many_inversing is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal false, ActiveRecord::Base.has_many_inversing
    end

    test "ActiveRecord::Base.has_many_inversing can be configured via config.active_record.has_many_inversing" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_1.rb", <<-RUBY
        Rails.application.config.active_record.has_many_inversing = true
      RUBY

      app "development"

      assert_equal true, ActiveRecord::Base.has_many_inversing
    end

    test "ActiveRecord::Base.automatic_scope_inversing is true by default for new apps" do
      app "development"

      assert_equal true, ActiveRecord::Base.automatic_scope_inversing
    end

    test "ActiveRecord::Base.automatic_scope_inversing is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal false, ActiveRecord::Base.automatic_scope_inversing
    end

    test "ActiveRecord::Base.automatic_scope_inversing can be configured via config.active_record.automatic_scope_inversing" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.active_record.automatic_scope_inversing = true
      RUBY

      app "development"

      assert_equal true, ActiveRecord::Base.automatic_scope_inversing
    end

    test "ActiveRecord.verify_foreign_keys_for_fixtures is true by default for new apps" do
      app "development"

      assert_equal true, ActiveRecord.verify_foreign_keys_for_fixtures
    end

    test "ActiveRecord.verify_foreign_keys_for_fixtures is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal false, ActiveRecord.verify_foreign_keys_for_fixtures
    end

    test "ActiveRecord.verify_foreign_keys_for_fixtures can be configured via config.active_record.verify_foreign_keys_for_fixtures" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.active_record.verify_foreign_keys_for_fixtures = true
      RUBY

      app "development"

      assert_equal true, ActiveRecord.verify_foreign_keys_for_fixtures
    end

    test "Deprecated Associations can be configured via config.active_record.deprecated_associations_options" do
      original_options = ActiveRecord.deprecated_associations_options

      # Make sure we test something.
      assert_not_equal :notify, original_options[:mode]
      assert_not original_options[:backtrace]

      add_to_config <<-RUBY
        config.active_record.deprecated_associations_options = { mode: :notify, backtrace: true }
      RUBY

      app "development"

      assert_equal :notify, ActiveRecord.deprecated_associations_options[:mode]
      assert ActiveRecord.deprecated_associations_options[:backtrace]
    ensure
      ActiveRecord.deprecated_associations_options = original_options
    end

    test "ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction is false by default for new apps" do
      app "development"

      assert_equal false, ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction
    end

    test "ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction is true by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal true, ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction
    end

    test "ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction can be configured via config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction = false
      RUBY

      app "development"

      assert_equal false, ActiveRecord::Base.run_commit_callbacks_on_first_saved_instances_in_transaction
    end

    test "config.active_record.use_legacy_signed_id_verifier is :generate_and_verify by default for new apps" do
      app "development"

      assert_equal :generate_and_verify, Rails.application.config.active_record.use_legacy_signed_id_verifier
    end

    test "Rails.application.message_verifiers['active_record/signed_id'] generates and verifies messages using legacy options when config.active_record.use_legacy_signed_id_verifier is :generate_and_verify" do
      add_to_config <<-RUBY
        config.active_record.use_legacy_signed_id_verifier = :generate_and_verify
        config.secret_key_base = "secret"
      RUBY

      app "development"

      signed_id_verifier = Rails.application.message_verifiers["active_record/signed_id"]

      secret = app.key_generator.generate_key("active_record/signed_id")
      legacy_verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA256", serializer: JSON, url_safe: true)

      assert_equal "message", legacy_verifier.verify(signed_id_verifier.generate("message"))
      assert_equal "message", signed_id_verifier.verify(legacy_verifier.generate("message"))
    end

    test "Rails.application.message_verifiers['active_record/signed_id'] verifies messages using legacy options when config.active_record.use_legacy_signed_id_verifier is :verify" do
      add_to_config <<-RUBY
        config.active_record.use_legacy_signed_id_verifier = :verify
        config.secret_key_base = "secret"
      RUBY

      app "development"

      signed_id_verifier = Rails.application.message_verifiers["active_record/signed_id"]

      secret = app.key_generator.generate_key("active_record/signed_id")
      legacy_verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA256", serializer: JSON, url_safe: true)

      assert_equal "message", signed_id_verifier.verify(legacy_verifier.generate("message"))
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        legacy_verifier.verify(signed_id_verifier.generate("message"))
      end
    end

    test "Rails.application.message_verifiers['active_record/signed_id'] does not use legacy options when config.active_record.use_legacy_signed_id_verifier is false" do
      add_to_config <<-RUBY
        config.active_record.use_legacy_signed_id_verifier = false
        config.secret_key_base = "secret"
      RUBY

      app "development"

      signed_id_verifier = Rails.application.message_verifiers["active_record/signed_id"]

      secret = app.key_generator.generate_key("active_record/signed_id")
      legacy_verifier = ActiveSupport::MessageVerifier.new(secret, digest: "SHA256", serializer: JSON, url_safe: true)

      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        signed_id_verifier.verify(legacy_verifier.generate("message"))
      end
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        legacy_verifier.verify(signed_id_verifier.generate("message"))
      end
    end

    test "raises when config.active_record.use_legacy_signed_id_verifier has invalid value" do
      add_to_config <<-RUBY
        config.active_record.use_legacy_signed_id_verifier = :invalid_option
      RUBY

      assert_raise(match: /config.active_record.use_legacy_signed_id_verifier/) do
        app "development"
      end
    end

    test "ActiveRecord.message_verifiers is Rails.application.message_verifiers" do
      app "development"

      assert_same Rails.application.message_verifiers, ActiveRecord.message_verifiers
    end

    test "PostgresqlAdapter.decode_dates is true by default for new apps" do
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "postgresql")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_dates
    end

    test "PostgresqlAdapter.decode_dates is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "postgresql")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal false, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_dates
    end

    test "PostgresqlAdapter.decode_dates can be configured via config.active_record.postgresql_adapter_decode_dates" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config "config.active_record.postgresql_adapter_decode_dates = true"

      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "postgresql")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_dates
    end

    test "PostgresqlAdapter.decode_money is true by default for new apps" do
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_money
    end

    test "PostgresqlAdapter.decode_money is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal false, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_money
    end

    test "PostgresqlAdapter.decode_money can be configured via config.active_record.postgresql_adapter_decode_money" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config "config.active_record.postgresql_adapter_decode_money = true"

      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_money
    end

    test "PostgresqlAdapter.decode_bytea is true by default for new apps" do
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_bytea
    end

    test "PostgresqlAdapter.decode_bytea is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal false, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_bytea
    end

    test "PostgresqlAdapter.decode_bytea can be configured via config.active_record.postgresql_adapter_decode_bytea" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config "config.active_record.postgresql_adapter_decode_bytea = true"

      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "development"

      assert_equal true, ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_bytea
    end

    test "SQLite3Adapter.strict_strings_by_default is true by default for new apps" do
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal true, ActiveRecord::ConnectionAdapters::SQLite3Adapter.strict_strings_by_default
    end

    test "SQLite3Adapter.strict_strings_by_default is false by default for upgraded apps" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal false, ActiveRecord::ConnectionAdapters::SQLite3Adapter.strict_strings_by_default

      Post.lease_connection.create_table :posts
      assert_nothing_raised do
        Post.lease_connection.add_index :posts, :non_existent
      end
    end

    test "SQLite3Adapter.strict_strings_by_default can be configured via config.active_record.sqlite3_adapter_strict_strings_by_default" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config "config.active_record.sqlite3_adapter_strict_strings_by_default = true"

      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal true, ActiveRecord::ConnectionAdapters::SQLite3Adapter.strict_strings_by_default
    end

    test "SQLite3Adapter.strict_strings_by_default can be configured via config.active_record.sqlite3_adapter_strict_strings_by_default in an initializer" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      remove_from_config '.*config\.load_defaults.*\n'
      app_file "config/initializers/new_framework_defaults_7_1.rb", <<-RUBY
        Rails.application.config.active_record.sqlite3_adapter_strict_strings_by_default = true
      RUBY
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end
      RUBY

      app "development"

      _ = ActiveRecord::Base
      assert_equal true, ActiveRecord::ConnectionAdapters::SQLite3Adapter.strict_strings_by_default

      Post.lease_connection.create_table :posts
      error = assert_raises(StandardError) do
        Post.lease_connection.add_index :posts, :non_existent
      end

      assert_match(/no such column: "?non_existent"?/, error.message)
    end

    test "ActiveSupport::MessageEncryptor.use_authenticated_message_encryption is true by default for new apps" do
      app "development"

      assert_equal true, ActiveSupport::MessageEncryptor.use_authenticated_message_encryption
    end

    test "ActiveSupport::MessageEncryptor.use_authenticated_message_encryption is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal false, ActiveSupport::MessageEncryptor.use_authenticated_message_encryption
    end

    test "ActiveSupport::MessageEncryptor.use_authenticated_message_encryption can be configured via config.active_support.use_authenticated_message_encryption" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_0.rb", <<-RUBY
        Rails.application.config.active_support.use_authenticated_message_encryption = true
      RUBY

      app "development"

      assert_equal true, ActiveSupport::MessageEncryptor.use_authenticated_message_encryption
    end

    test "ActiveSupport::Digest.hash_digest_class is OpenSSL::Digest::SHA256 by default for new apps" do
      app "development"

      assert_equal OpenSSL::Digest::SHA256, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::Digest.hash_digest_class is OpenSSL::Digest::MD5 by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal OpenSSL::Digest::MD5, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::Digest.hash_digest_class can be configured via config.active_support.hash_digest_class" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/custom_digest_class.rb", <<-RUBY
        Rails.application.config.active_support.hash_digest_class = OpenSSL::Digest::SHA256
      RUBY

      app "development"

      assert_equal OpenSSL::Digest::SHA256, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::KeyGenerator.hash_digest_class is OpenSSL::Digest::SHA256 by default for new apps" do
      app "development"

      assert_equal OpenSSL::Digest::SHA256, ActiveSupport::KeyGenerator.hash_digest_class
    end

    test "ActiveSupport::KeyGenerator.hash_digest_class is OpenSSL::Digest::SHA1 by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal OpenSSL::Digest::SHA1, ActiveSupport::KeyGenerator.hash_digest_class
    end

    test "ActiveSupport::KeyGenerator.hash_digest_class can be configured via config.active_support.key_generator_hash_digest_class" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/custom_key_generator_digest_class.rb", <<-RUBY
        Rails.application.config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA256
      RUBY

      app "development"

      assert_equal OpenSSL::Digest::SHA256, ActiveSupport::KeyGenerator.hash_digest_class
    end

    test "ActiveSupport.test_parallelization_threshold can be configured via config.active_support.test_parallelization_threshold" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/environments/test.rb", <<-RUBY
        Rails.application.configure do
          config.active_support.test_parallelization_threshold = 1234
        end
      RUBY

      app "test"

      assert_equal 1234, ActiveSupport.test_parallelization_threshold
    end

    test "ActiveSupport.parallelize_test_databases can be configured via config.active_support.parallelize_test_databases" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/environments/test.rb", <<-RUBY
        Rails.application.configure do
          config.active_support.parallelize_test_databases = false
        end
      RUBY

      app "test"

      assert_not ActiveSupport.parallelize_test_databases
    end

    test "config.active_job.verbose_enqueue_logs defaults to true in development" do
      restore_default_config
      app "development"

      assert ActiveJob.verbose_enqueue_logs
    end

    test "config.active_job.verbose_enqueue_logs defaults to false in production" do
      app "production"

      assert_not ActiveJob.verbose_enqueue_logs
    end

    test "config.active_job.enqueue_after_transaction_commit defaults to true for new apps" do
      app "production"

      assert ActiveRecord::Base
      assert_equal true, ActiveJob::Base.enqueue_after_transaction_commit
    end

    test "config.active_job.enqueue_after_transaction_commit can be set to false for new apps" do
      app_file "config/initializers/enqueue_after_transaction_commit.rb", <<-RUBY
        Rails.application.config.active_job.enqueue_after_transaction_commit = false
      RUBY

      app "production"

      assert ActiveRecord::Base
      assert_equal false, ActiveJob::Base.enqueue_after_transaction_commit
    end

    test "config.active_job.enqueue_after_transaction_commit defaults to false for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "production"

      assert ActiveRecord::Base
      assert_equal false, ActiveJob::Base.enqueue_after_transaction_commit
    end

    test "config.active_job.enqueue_after_transaction_commit can be set to true for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/enqueue_after_transaction_commit.rb", <<-RUBY
        Rails.application.config.active_job.enqueue_after_transaction_commit = true
      RUBY

      app "production"

      assert ActiveRecord::Base
      assert_equal true, ActiveJob::Base.enqueue_after_transaction_commit
    end

    test "active record job queue is set" do
      app "development"

      assert_equal({}, ActiveRecord.queues)
    end

    test "destroy association async job should be loaded in configs" do
      app "development"

      assert_equal ActiveRecord::DestroyAssociationAsyncJob, ActiveRecord::Base.destroy_association_async_job
    end

    test "ActiveRecord::Base.destroy_association_async_job can be configured via config.active_record.destroy_association_async_job" do
      class ::DummyDestroyAssociationAsyncJob; end

      app_file "config/environments/test.rb", <<-RUBY
        Rails.application.configure do
          config.active_record.destroy_association_async_job = "DummyDestroyAssociationAsyncJob"
        end
      RUBY

      app "test"

      assert_equal DummyDestroyAssociationAsyncJob, ActiveRecord::Base.destroy_association_async_job
    end

    test "destroy association async batch size is nil by default" do
      app "development"

      assert_nil ActiveRecord::Base.destroy_association_async_batch_size
    end

    test "destroy association async batch size can be set in configs" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.active_record.destroy_association_async_batch_size = 100
        end
      RUBY

      app "development"

      assert_equal 100, ActiveRecord::Base.destroy_association_async_batch_size
    end

    test "ActionView::Helpers::FormTagHelper.default_enforce_utf8 is false by default" do
      app "development"
      assert_equal false, ActionView::Helpers::FormTagHelper.default_enforce_utf8
    end

    test "ActionView::Helpers::FormTagHelper.default_enforce_utf8 is true in an upgraded app" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "5.2"'

      app "development"

      assert_equal true, ActionView::Helpers::FormTagHelper.default_enforce_utf8
    end

    test "ActionView::Helpers::FormTagHelper.default_enforce_utf8 can be configured via config.action_view.default_enforce_utf8" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_0.rb", <<-RUBY
        Rails.application.config.action_view.default_enforce_utf8 = true
      RUBY

      app "development"

      assert_equal true, ActionView::Helpers::FormTagHelper.default_enforce_utf8
    end

    test "ActionView::Helpers::UrlHelper.button_to_generates_button_tag is true by default" do
      app "development"
      assert_equal true, ActionView::Helpers::UrlHelper.button_to_generates_button_tag
    end

    test "ActionView::Helpers::UrlHelper.button_to_generates_button_tag is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'
      app "development"

      assert_equal false, ActionView::Helpers::UrlHelper.button_to_generates_button_tag
    end

    test "ActionView::Helpers::UrlHelper.button_to_generates_button_tag can be configured via config.action_view.button_to_generates_button_tag" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.action_view.button_to_generates_button_tag = true
      RUBY

      app "development"

      assert_equal true, ActionView::Helpers::UrlHelper.button_to_generates_button_tag
    end

    test "ActionView::Helpers::AssetTagHelper.image_loading is nil by default" do
      app "development"
      assert_nil ActionView::Helpers::AssetTagHelper.image_loading
    end

    test "ActionView::Helpers::AssetTagHelper.image_loading can be configured via config.action_view.image_loading" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.action_view.image_loading = "lazy"
        end
      RUBY

      app "development"

      assert_equal "lazy", ActionView::Helpers::AssetTagHelper.image_loading
    end

    test "ActionView::Helpers::AssetTagHelper.image_decoding is nil by default" do
      app "development"
      assert_nil ActionView::Helpers::AssetTagHelper.image_decoding
    end

    test "ActionView::Helpers::AssetTagHelper.image_decoding can be configured via config.action_view.image_decoding" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.action_view.image_decoding = "async"
        end
      RUBY

      app "development"

      assert_equal "async", ActionView::Helpers::AssetTagHelper.image_decoding
    end

    test "ActionView::Helpers::AssetTagHelper.preload_links_header is true by default" do
      app "development"
      assert_equal true, ActionView::Helpers::AssetTagHelper.preload_links_header
    end

    test "ActionView::Helpers::AssetTagHelper.preload_links_header is nil by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'
      app "development"

      assert_nil ActionView::Helpers::AssetTagHelper.preload_links_header
    end

    test "ActionView::Helpers::AssetTagHelper.preload_links_header can be configured via config.action_view.preload_links_header" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.action_view.preload_links_header = false
        end
      RUBY

      app "development"

      assert_equal false, ActionView::Helpers::AssetTagHelper.preload_links_header
    end

    test "ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default is true by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      app "development"

      assert_equal true, ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default
    end

    test "ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default can be configured via config.action_view.apply_stylesheet_media_default" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.action_view.apply_stylesheet_media_default = false
      RUBY

      app "development"

      assert_equal false, ActionView::Helpers::AssetTagHelper.apply_stylesheet_media_default
    end

    test "stylesheet_link_tag sets the link header by default" do
      app_file "app/controllers/pages_controller.rb", <<-RUBY
      class PagesController < ApplicationController
        def index
          render inline: "<%= stylesheet_link_tag '/application.css' %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          root to: "pages#index"
        end
      RUBY

      app "development"

      get "/"
      assert_match %r[<link rel="stylesheet" href="/application.css" />], last_response.body
      assert_equal "</application.css>; rel=preload; as=style; nopush", last_response.headers["link"]
    end

    test "stylesheet_link_tag doesn't set the link header when disabled" do
      app_file "config/initializers/action_view.rb", <<-RUBY
        Rails.application.config.action_view.preload_links_header = false
      RUBY

      app_file "app/controllers/pages_controller.rb", <<-RUBY
      class PagesController < ApplicationController
        def index
          render inline: "<%= stylesheet_link_tag '/application.css' %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          root to: "pages#index"
        end
      RUBY

      app "development"

      get "/"
      assert_match %r[<link rel="stylesheet" href="/application.css" />], last_response.body
      assert_nil last_response.headers["link"]
    end

    test "javascript_include_tag sets the link header by default" do
      app_file "app/controllers/pages_controller.rb", <<-RUBY
      class PagesController < ApplicationController
        def index
          render inline: "<%= javascript_include_tag '/application.js' %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          root to: "pages#index"
        end
      RUBY

      app "development"

      get "/"
      assert_match %r[<script src="/application.js"></script>], last_response.body
      assert_equal "</application.js>; rel=preload; as=script; nopush", last_response.headers["link"]
    end

    test "javascript_include_tag doesn't set the link header when disabled" do
      app_file "config/initializers/action_view.rb", <<-RUBY
        Rails.application.config.action_view.preload_links_header = false
      RUBY

      app_file "app/controllers/pages_controller.rb", <<-RUBY
      class PagesController < ApplicationController
        def index
          render inline: "<%= javascript_include_tag '/application.js' %>"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          root to: "pages#index"
        end
      RUBY

      app "development"

      get "/"
      assert_match %r[<script src="/application.js"></script>], last_response.body
      assert_nil last_response.headers["link"]
    end

    test "ActiveJob::Base.retry_jitter is 0.15 by default for new apps" do
      app "development"

      assert_equal 0.15, ActiveJob::Base.retry_jitter
    end

    test "ActiveJob::Base.retry_jitter is 0.0 by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      app "development"

      assert_equal 0.0, ActiveJob::Base.retry_jitter
    end

    test "ActiveJob::Base.retry_jitter can be set by config" do
      app "development"

      Rails.application.config.active_job.retry_jitter = 0.22

      assert_equal 0.22, ActiveJob::Base.retry_jitter
    end

    test "Rails.application.config.action_dispatch.cookies_same_site_protection is :lax by default" do
      app "production"

      assert_equal :lax, Rails.application.config.action_dispatch.cookies_same_site_protection
    end

    test "Rails.application.config.action_dispatch.cookies_same_site_protection is :lax can be overridden" do
      app_file "config/environments/production.rb", <<~RUBY
        Rails.application.configure do
          config.action_dispatch.cookies_same_site_protection = :strict
        end
      RUBY

      app "production"

      assert_equal :strict, Rails.application.config.action_dispatch.cookies_same_site_protection
    end

    test "Rails.application.config.action_dispatch.cookies_same_site_protection is :lax in 6.1 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_equal :lax, Rails.application.config.action_dispatch.cookies_same_site_protection
    end

    test "Rails.application.config.action_dispatch.ssl_default_redirect_status is 308 in 6.1 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "production"

      assert_equal 308, Rails.application.config.action_dispatch.ssl_default_redirect_status
    end

    test "Rails.application.config.action_dispatch.ssl_default_redirect_status can be configured in an initializer" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app_file "config/initializers/new_framework_defaults_6_1.rb", <<-RUBY
        Rails.application.config.action_dispatch.ssl_default_redirect_status = 308
      RUBY

      app "production"

      assert_equal 308, Rails.application.config.action_dispatch.ssl_default_redirect_status
    end

    test "Rails.application.config.action_dispatch.strict_freshness is false by default for older applications" do
      remove_from_config '.*config\.load_defaults.*\n'
      app "development"

      assert_equal false, Rails.application.config.action_dispatch.strict_freshness
    end

    test "Rails.application.config.action_dispatch.strict_freshness can be configured in an initializer" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config <<-RUBY
        config.action_dispatch.strict_freshness = true
      RUBY

      app "development"

      assert_equal true, ActionDispatch::Http::Cache::Request.strict_freshness
    end

    test "config.action_dispatch.verbose_redirect_logs is true in development" do
      restore_default_config
      app "development"

      assert ActionDispatch.verbose_redirect_logs
    end

    test "config.action_dispatch.verbose_redirect_logs is false in production" do
      app "production"

      assert_not ActionDispatch.verbose_redirect_logs
    end

    test "Rails.application.config.action_mailer.smtp_settings have open_timeout and read_timeout defined as 5 in 7.0 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config <<-RUBY
        config.action_mailer.smtp_settings = { domain: "example.com" }
        config.load_defaults "7.0"
      RUBY

      app "development"

      smtp_settings = { domain: "example.com", open_timeout: 5, read_timeout: 5 }

      assert_equal smtp_settings, ActionMailer::Base.smtp_settings
      assert_equal smtp_settings, Rails.configuration.action_mailer.smtp_settings
    end

    test "Rails.application.config.action_mailer.smtp_settings does not have open_timeout and read_timeout configured on other versions" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config <<-RUBY
        config.action_mailer.smtp_settings = { domain: "example.com" }
      RUBY

      app "development"

      smtp_settings = { domain: "example.com" }

      assert_equal smtp_settings, ActionMailer::Base.smtp_settings
    end

    test "Rails.application.config.action_mailer.smtp_settings = nil fallback to ActionMailer::Base.smtp_settings" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config <<-RUBY
        ActiveSupport.on_load(:action_mailer) do
          self.smtp_settings = { domain: "example.com" }
        end
        config.load_defaults "7.0"
      RUBY

      app "development"

      smtp_settings = { domain: "example.com", open_timeout: 5, read_timeout: 5 }

      assert_equal smtp_settings, ActionMailer::Base.smtp_settings
      assert_nil Rails.configuration.action_mailer.smtp_settings
    end

    test "Rails.application.config.action_mailer.smtp_settings = nil and ActionMailer::Base.smtp_settings = nil do not configure smtp_timeout" do
      ActionMailer::Base.smtp_settings = nil

      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config <<-RUBY
        config.action_mailer.smtp_settings = nil
        config.load_defaults "7.0"
      RUBY

      app "development"

      assert_nil Rails.configuration.action_mailer.smtp_settings
      assert_nil ActionMailer::Base.smtp_settings
    end

    test "ActiveSupport.utc_to_local_returns_utc_offset_times is true in 6.1 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_equal true, ActiveSupport.utc_to_local_returns_utc_offset_times
    end

    test "ActiveSupport.utc_to_local_returns_utc_offset_times is false in 6.0 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal false, ActiveSupport.utc_to_local_returns_utc_offset_times
    end

    test "ActiveSupport.utc_to_local_returns_utc_offset_times can be configured in an initializer" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app_file "config/initializers/new_framework_defaults_6_1.rb", <<-RUBY
        ActiveSupport.utc_to_local_returns_utc_offset_times = true
      RUBY

      app "development"

      assert_equal true, ActiveSupport.utc_to_local_returns_utc_offset_times
    end

    test "ActiveStorage.queues[:analysis] is :active_storage_analysis by default in 6.0" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal :active_storage_analysis, ActiveStorage.queues[:analysis]
    end

    test "ActiveStorage.queues[:analysis] is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_nil ActiveStorage.queues[:analysis]
    end

    test "ActiveStorage.queues[:analysis] is nil without Rails 6 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_nil ActiveStorage.queues[:analysis]
    end

    test "ActiveStorage.queues[:purge] is :active_storage_purge by default in 6.0" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal :active_storage_purge, ActiveStorage.queues[:purge]
    end

    test "ActiveStorage.queues[:purge] is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_nil ActiveStorage.queues[:purge]
    end

    test "ActiveStorage.queues[:purge] is nil without Rails 6 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_nil ActiveStorage.queues[:purge]
    end

    test "ActiveStorage.queues[:mirror] is nil without Rails 6 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_nil ActiveStorage.queues[:mirror]
    end

    test "ActiveStorage.queues[:mirror] is nil by default" do
      app "development"

      assert_nil ActiveStorage.queues[:mirror]
    end

    test "ActionCable.server.config.cable is set when missing configuration for the current environment" do
      quietly do
        app "missing"
      end

      assert_kind_of ActiveSupport::HashWithIndifferentAccess, ActionCable.server.config.cable
    end

    test "action_text.config.attachment_tag_name is 'action-text-attachment' with Rails 6 defaults" do
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_equal "action-text-attachment", ActionText::Attachment.tag_name
    end

    test "action_text.config.attachment_tag_name is 'action-text-attachment' without defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal "action-text-attachment", ActionText::Attachment.tag_name
    end

    test "action_text.config.attachment_tag_name is can be overridden" do
      add_to_config "config.action_text.attachment_tag_name = 'link'"

      app "development"

      assert_equal "link", ActionText::Attachment.tag_name
    end

    test "ActionMailbox.logger is Rails.logger by default" do
      app "development"

      assert_equal Rails.logger, ActionMailbox.logger
    end

    test "ActionMailbox.logger can be configured" do
      app_file "lib/my_logger.rb", <<-RUBY
        require "logger"
        class MyLogger < ::Logger
        end
      RUBY

      add_to_config <<-RUBY
        require "my_logger"
        config.action_mailbox.logger = MyLogger.new(STDOUT)
      RUBY

      app "development"

      assert_equal "MyLogger", ActionMailbox.logger.class.name
    end

    test "ActionMailbox.incinerate_after is 30.days by default" do
      app "development"

      assert_equal 30.days, ActionMailbox.incinerate_after
    end

    test "ActionMailbox.incinerate_after can be configured" do
      add_to_config <<-RUBY
        config.action_mailbox.incinerate_after = 14.days
      RUBY

      app "development"

      assert_equal 14.days, ActionMailbox.incinerate_after
    end

    test "ActionMailbox.queues[:incineration] is :action_mailbox_incineration by default in 6.0" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal :action_mailbox_incineration, ActionMailbox.queues[:incineration]
    end

    test "ActionMailbox.queues[:incineration] is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_nil ActionMailbox.queues[:incineration]
    end

    test "ActionMailbox.queues[:incineration] can be configured" do
      add_to_config <<-RUBY
        config.action_mailbox.queues.incineration = :another_queue
      RUBY

      app "development"

      assert_equal :another_queue, ActionMailbox.queues[:incineration]
    end

    test "ActionMailbox.queues[:routing] is :action_mailbox_routing by default in 6.0" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal :action_mailbox_routing, ActionMailbox.queues[:routing]
    end

    test "ActionMailbox.queues[:routing] is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      assert_nil ActionMailbox.queues[:routing]
    end

    test "ActionMailbox.queues[:routing] can be configured" do
      add_to_config <<-RUBY
        config.action_mailbox.queues.routing = :another_queue
      RUBY

      app "development"

      assert_equal :another_queue, ActionMailbox.queues[:routing]
    end

    test "ActionMailbox.storage_service is nil by default (default service)" do
      app "development"
      assert_nil(ActionMailbox.storage_service)
    end

    test "ActionMailbox.storage_service can be configured" do
      add_to_config <<-RUBY
        config.active_storage.service_configurations = {
          email: {
            root: "#{Dir.tmpdir}/email",
            service: "Disk"
          }
        }
        config.action_mailbox.storage_service = :email
      RUBY
      app "development"
      assert_equal(:email, ActionMailbox.storage_service)
    end

    test "ActionMailer::Base.delivery_job is ActionMailer::MailDeliveryJob by default" do
      app "development"

      assert_equal ActionMailer::MailDeliveryJob, ActionMailer::Base.delivery_job
    end

    test "ActiveRecord::Base.filter_attributes should equal to filter_parameters" do
      app_file "config/initializers/filter_parameters_logging.rb", <<-RUBY
        Rails.application.config.filter_parameters += [ :password, :credit_card_number ]
      RUBY
      app "development"
      assert_equal [ :password, :credit_card_number ], Rails.application.config.filter_parameters
      assert_equal [ :password, :credit_card_number ], ActiveRecord::Base.filter_attributes
    end

    test "encrypted attributes are added to record's filter_attributes by default" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
          encrypts :content
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
      RUBY

      app "production"

      assert_includes Post.filter_attributes, :content
      assert_not_includes ActiveRecord::Base.filter_attributes, :content
    end

    test "encrypted attributes are not added to record filter_attributes if disabled" do
      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
          encrypts :content
        end
      RUBY

      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true

        config.active_record.encryption.add_to_filter_parameters = false
      RUBY

      app "production"

      assert_not_includes Post.filter_attributes, :content
      assert_not_includes ActiveRecord::Base.filter_attributes, :content
    end

    test "ActiveRecord::Encryption.config is ready when accessed before loading ActiveRecord::Base" do
      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = false

        config.active_record.encryption.primary_key = "dummy_key"
        config.active_record.encryption.extend_queries = true
      RUBY

      app "development"

      # Encryption config is ready to be accessed
      assert_equal "dummy_key", ActiveRecord::Encryption.config.primary_key
      assert ActiveRecord::Encryption.config.extend_queries

      # ActiveRecord::Base is not loaded yet (lazy loading preserved)
      active_record_loaded = ActiveRecord.autoload?(:Base).nil?
      assert_not active_record_loaded

      # When ActiveRecord::Base loaded, extended queries should be installed
      assert ActiveRecord::Base.include?(ActiveRecord::Encryption::ExtendedDeterministicQueries::CoreQueries)
    end

    test "ActiveRecord::Encryption.config is ready for encrypted attributes when app is lazy loaded" do
      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = false
      RUBY

      app_file "config/initializers/active_record.rb", <<-RUBY
        Rails.application.config.active_record.encryption.primary_key = "dummy_key"
        Rails.application.config.active_record.encryption.previous = [ { key_provider: MyOldKeyProvider.new } ]

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
          ActiveRecord::Migration.verbose = false
          ActiveRecord::Schema.define(version: 1) do
            create_table :posts do |t|
              t.string :content
            end
          end
          ActiveRecord::Base.schema_cache.add("posts")
        end
      RUBY

      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
          encrypts :content, key_provider: MyCustomKeyProvider.new(ActiveRecord::Encryption.config.primary_key)
        end
      RUBY

      app "development"

      assert_kind_of ::MyOldKeyProvider, Post.attribute_types["content"].previous_schemes.first.key_provider
      assert_kind_of ::MyCustomKeyProvider, Post.attribute_types["content"].scheme.key_provider
      assert_equal "dummy_key", Post.attribute_types["content"].scheme.key_provider.primary_key
    end

    test "ActiveRecord::Encryption.config is ready for encrypted attributes when app is eager loaded" do
      add_to_config <<-RUBY
        config.enable_reloading = false
        config.eager_load = true
      RUBY

      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
          encrypts :content, key_provider: MyCustomKeyProvider.new(ActiveRecord::Encryption.config.primary_key)
        end
      RUBY

      app_file "config/initializers/active_record.rb", <<-RUBY
        Rails.application.config.active_record.encryption.primary_key = "dummy_key"
        Rails.application.config.active_record.encryption.previous = [ { key_provider: MyOldKeyProvider.new } ]

        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        end
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Schema.define(version: 1) do
          create_table :posts do |t|
            t.string :content
          end
        end

        ActiveRecord::Base.schema_cache.add("posts")
      RUBY

      app "production"

      assert_kind_of ::MyOldKeyProvider, Post.attribute_types["content"].previous_schemes.first&.key_provider
      assert_kind_of ::MyCustomKeyProvider, Post.attribute_types["content"].scheme.key_provider
      assert_equal "dummy_key", Post.attribute_types["content"].scheme.key_provider.primary_key
    end

    test "ActiveStorage.routes_prefix can be configured via config.active_storage.routes_prefix" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.active_storage.routes_prefix = '/files'
        end
      RUBY

      output = rails("routes", "-g", "active_storage")
      assert_equal <<~MESSAGE, output
                               Prefix Verb URI Pattern                                                                        Controller#Action
                   rails_service_blob GET  /files/blobs/redirect/:signed_id/*filename(.:format)                               active_storage/blobs/redirect#show
             rails_service_blob_proxy GET  /files/blobs/proxy/:signed_id/*filename(.:format)                                  active_storage/blobs/proxy#show
                                      GET  /files/blobs/:signed_id/*filename(.:format)                                        active_storage/blobs/redirect#show
            rails_blob_representation GET  /files/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations/redirect#show
      rails_blob_representation_proxy GET  /files/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format)    active_storage/representations/proxy#show
                                      GET  /files/representations/:signed_blob_id/:variation_key/*filename(.:format)          active_storage/representations/redirect#show
                   rails_disk_service GET  /files/disk/:encoded_key/*filename(.:format)                                       active_storage/disk#show
            update_rails_disk_service PUT  /files/disk/:encoded_token(.:format)                                               active_storage/disk#update
                 rails_direct_uploads POST /files/direct_uploads(.:format)                                                    active_storage/direct_uploads#create
      MESSAGE
    end

    test "ActiveStorage.analyzers default value" do
      app "development"

      assert_equal [
        ActiveStorage::Analyzer::ImageAnalyzer::Vips,
        ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick,
        ActiveStorage::Analyzer::VideoAnalyzer,
        ActiveStorage::Analyzer::AudioAnalyzer
      ], ActiveStorage.analyzers
    end

    test "ActiveStorage.analyzers can be configured to be an empty array" do
      add_to_config <<-RUBY
        config.active_storage.analyzers = []
      RUBY

      app "development"

      assert_empty ActiveStorage.analyzers
    end

    test "ActiveStorage.analyzers can be configured to custom analyzers" do
      add_to_config <<-RUBY
        config.active_storage.analyzers = [ ActiveStorage::Analyzer::ImageAnalyzer::Vips ]
      RUBY

      app "development"

      assert_equal [ ActiveStorage::Analyzer::ImageAnalyzer::Vips ], ActiveStorage.analyzers
    end

    test "ActiveStorage.draw_routes can be configured via config.active_storage.draw_routes" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.active_storage.draw_routes = false
        end
      RUBY

      output = rails("routes")
      assert_not_includes(output, "rails_service_blob")
      assert_not_includes(output, "rails_blob_representation")
      assert_not_includes(output, "rails_disk_service")
      assert_not_includes(output, "update_rails_disk_service")
      assert_not_includes(output, "rails_direct_uploads")
    end

    test "ActiveStorage.video_preview_arguments uses the old arguments without Rails 7 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal "-y -vframes 1 -f image2",
        ActiveStorage.video_preview_arguments
    end

    test "ActiveStorage.video_preview_arguments uses the new arguments by default" do
      app "development"

      assert_equal \
        "-vf 'select=eq(n\\,0)+eq(key\\,1)+gt(scene\\,0.015),loop=loop=-1:size=2,trim=start_frame=1' -frames:v 1 -f image2",
        ActiveStorage.video_preview_arguments
    end

    test "ActiveStorage.variant_processor uses mini_magick without Rails 7 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal :mini_magick, ActiveStorage.variant_processor
    end

    test "ActiveStorage.variant_processor uses vips by default" do
      app "development"

      assert_equal :vips, ActiveStorage.variant_processor
    end

    test "ActiveStorage.analyzers doesn't contain nil when variant_processor = nil" do
      add_to_config "config.active_storage.variant_processor = nil"

      app "development"

      assert_not_includes ActiveStorage.analyzers, nil
    end

    test "ActiveStorage.supported_image_processing_methods can be configured via config.active_storage.supported_image_processing_methods" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/add_image_processing_methods.rb", <<-RUBY
        Rails.application.config.active_storage.supported_image_processing_methods = ["write", "set"]
      RUBY

      app "development"

      assert ActiveStorage.supported_image_processing_methods.include?("write")
      assert ActiveStorage.supported_image_processing_methods.include?("set")
    end

    test "ActiveStorage.unsupported_image_processing_arguments can be configured via config.active_storage.unsupported_image_processing_arguments" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/add_image_processing_arguments.rb", <<-RUBY
      Rails.application.config.active_storage.unsupported_image_processing_arguments = %w(
        -write
        -danger
      )
      RUBY

      app "development"

      assert ActiveStorage.unsupported_image_processing_arguments.include?("-danger")
      assert_not ActiveStorage.unsupported_image_processing_arguments.include?("-set")
    end

    test "hosts include .localhost in development" do
      app "development"
      assert_includes Rails.application.config.hosts, ".localhost"
    end

    test "hosts include .test in development" do
      app "development"
      assert_includes Rails.application.config.hosts, ".test"
    end

    test "hosts reads multiple values from RAILS_DEVELOPMENT_HOSTS" do
      host = "agoodhost.com"
      another_host = "bananapants.com"
      switch_development_hosts_to(host, another_host) do
        app "development"
        assert_includes Rails.application.config.hosts, host
        assert_includes Rails.application.config.hosts, another_host
      end
    end

    test "hosts reads multiple values from RAILS_DEVELOPMENT_HOSTS and trims white space" do
      host = "agoodhost.com"
      host_with_white_space = "  #{host} "
      another_host = "bananapants.com"
      another_host_with_white_space = "     #{another_host}"
      switch_development_hosts_to(host_with_white_space, another_host_with_white_space) do
        app "development"
        assert_includes Rails.application.config.hosts, host
        assert_includes Rails.application.config.hosts, another_host
      end
    end

    test "hosts reads from RAILS_DEVELOPMENT_HOSTS" do
      host = "agoodhost.com"
      switch_development_hosts_to(host) do
        app "development"
        assert_includes Rails.application.config.hosts, host
      end
    end

    test "hosts does not read from RAILS_DEVELOPMENT_HOSTS in production" do
      host = "agoodhost.com"
      switch_development_hosts_to(host) do
        app "production"
        assert_not_includes Rails.application.config.hosts, host
      end
    end

    test "disable_sandbox is false by default" do
      app "development"

      assert_equal false, Rails.configuration.disable_sandbox
    end

    test "disable_sandbox can be overridden" do
      add_to_config <<-RUBY
        config.disable_sandbox = true
      RUBY

      app "development"

      assert Rails.configuration.disable_sandbox
    end

    test "rake_eager_load is false by default" do
      app "development"
      assert_equal false,  Rails.application.config.rake_eager_load
    end

    test "rake_eager_load is set correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.rake_eager_load = true
      RUBY

      app "development"

      assert_equal true, Rails.application.config.rake_eager_load
    end

    test "ActiveSupport::Messages::Codec.default_serializer is :json_allow_marshal by default for new apps" do
      app "development"

      assert_equal :json_allow_marshal, ActiveSupport::Messages::Codec.default_serializer
    end

    test "ActiveSupport::Messages::Codec.default_serializer is :marshal by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal :marshal, ActiveSupport::Messages::Codec.default_serializer
    end

    test "ActiveSupport::Messages::Codec.default_serializer can be configured via config.active_support.message_serializer" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_1.rb", <<~RUBY
        Rails.application.config.active_support.message_serializer = :json_allow_marshal
      RUBY

      app "development"

      assert_equal :json_allow_marshal, ActiveSupport::Messages::Codec.default_serializer
    end

    test "ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata is true by default for new apps" do
      app "development"

      assert ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
    end

    test "ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_not ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
    end

    test "ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata can be configured via config.active_support.use_message_serializer_for_metadata" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_7_1.rb", <<~RUBY
        Rails.application.config.active_support.use_message_serializer_for_metadata = true
      RUBY

      app "development"

      assert ActiveSupport::Messages::Metadata.use_message_serializer_for_metadata
    end

    test "unknown_asset_fallback is false by default" do
      app "development"

      assert_equal false, Rails.application.config.assets.unknown_asset_fallback
    end

    test "action_dispatch.log_rescued_responses is true by default" do
      app "development"

      assert_equal true, Rails.application.env_config["action_dispatch.log_rescued_responses"]
    end

    test "action_dispatch.log_rescued_responses can be configured" do
      add_to_config <<-RUBY
        config.action_dispatch.log_rescued_responses = false
      RUBY

      app "development"

      assert_equal false, Rails.application.env_config["action_dispatch.log_rescued_responses"]
    end

    test "app starts with LocalCache middleware" do
      app "development"

      assert(Rails.application.config.middleware.map(&:name).include?("ActiveSupport::Cache::Strategy::LocalCache"))

      local_cache_index = Rails.application.config.middleware.map(&:name).index("ActiveSupport::Cache::Strategy::LocalCache")
      logger_index = Rails.application.config.middleware.map(&:name).index("Rails::Rack::Logger")
      assert local_cache_index < logger_index
    end

    test "LocalCache middleware can be moved via app config" do
      # you can't move Rails.cache.middleware as it doesn't exist yet
      add_to_config "config.middleware.move_after(Rails::Rack::Logger, ActiveSupport::Cache::Strategy::LocalCache)"

      app "development"

      local_cache_index = Rails.application.config.middleware.map(&:name).index("ActiveSupport::Cache::Strategy::LocalCache")
      logger_index = Rails.application.config.middleware.map(&:name).index("Rails::Rack::Logger")
      assert local_cache_index > logger_index
    end

    test "LocalCache middleware can be moved via initializer" do
      app_file "config/initializers/move_local_cache_middleware.rb", <<~RUBY
        Rails.application.config.middleware.move_after(Rails::Rack::Logger, Rails.cache.middleware)
      RUBY

      app "development"

      local_cache_index = Rails.application.config.middleware.map(&:name).index("ActiveSupport::Cache::Strategy::LocalCache")
      logger_index = Rails.application.config.middleware.map(&:name).index("Rails::Rack::Logger")
      assert local_cache_index > logger_index
    end

    test "LocalCache middleware can be removed via app config" do
      # you can't delete Rails.cache.middleware as it doesn't exist yet
      add_to_config "config.middleware.delete(ActiveSupport::Cache::Strategy::LocalCache)"

      app "development"

      assert_not(Rails.application.config.middleware.map(&:name).include?("ActiveSupport::Cache::Strategy::LocalCache"))
    end

    test "LocalCache middleware can be removed via initializer" do
      app_file "config/initializers/remove_local_cache_middleware.rb", <<~RUBY
        Rails.application.config.middleware.delete(Rails.cache.middleware)
      RUBY

      app "development"

      assert_not(Rails.application.config.middleware.map(&:name).include?("ActiveSupport::Cache::Strategy::LocalCache"))
    end

    test "custom middleware with overridden names can be added, moved, or deleted" do
      app_file "config/initializers/add_custom_middleware.rb", <<~RUBY
        class CustomMiddlewareOne
          def self.name
            "1st custom middleware"
          end
          def initialize(app, *args); end
          def new(app); self; end
        end

        class CustomMiddlewareTwo
          def initialize(app, *args); end
          def new(app); self; end
        end

        class CustomMiddlewareThree
          def self.name
            "3rd custom middleware"
          end
          def initialize(app, *args); end
          def new(app); self; end
        end

        Rails.application.config.middleware.use(CustomMiddlewareOne)
        Rails.application.config.middleware.use(CustomMiddlewareTwo)
        Rails.application.config.middleware.use(CustomMiddlewareThree)
        Rails.application.config.middleware.move_after(CustomMiddlewareTwo, CustomMiddlewareOne)
        Rails.application.config.middleware.delete(CustomMiddlewareThree)
      RUBY

      app "development"

      custom_middleware_one = Rails.application.config.middleware.map(&:name).index("1st custom middleware")
      custom_middleware_two = Rails.application.config.middleware.map(&:name).index("CustomMiddlewareTwo")
      assert custom_middleware_one > custom_middleware_two

      assert_nil Rails.application.config.middleware.map(&:name).index("3rd custom middleware")
    end

    test "Rails.application.deprecators includes framework deprecators" do
      app "production"

      assert_includes Rails.application.deprecators.each, ActiveSupport::Deprecation._instance
      assert_equal ActionCable.deprecator, Rails.application.deprecators[:action_cable]
      assert_equal AbstractController.deprecator, Rails.application.deprecators[:action_controller]
      assert_equal ActionController.deprecator, Rails.application.deprecators[:action_controller]
      assert_equal ActionDispatch.deprecator, Rails.application.deprecators[:action_dispatch]
      assert_equal ActionMailbox.deprecator, Rails.application.deprecators[:action_mailbox]
      assert_equal ActionMailer.deprecator, Rails.application.deprecators[:action_mailer]
      assert_equal ActionText.deprecator, Rails.application.deprecators[:action_text]
      assert_equal ActionView.deprecator, Rails.application.deprecators[:action_view]
      assert_equal ActiveJob.deprecator, Rails.application.deprecators[:active_job]
      assert_equal ActiveModel.deprecator, Rails.application.deprecators[:active_model]
      assert_equal ActiveRecord.deprecator, Rails.application.deprecators[:active_record]
      assert_equal ActiveStorage.deprecator, Rails.application.deprecators[:active_storage]
      assert_equal ActiveSupport.deprecator, Rails.application.deprecators[:active_support]
      assert_equal Rails.deprecator, Rails.application.deprecators[:railties]
    end

    test "can entirely opt out of deprecation warnings" do
      add_to_config "config.active_support.report_deprecations = false"

      app "production"

      assert_predicate Rails.application.deprecators.each, :any?

      Rails.application.deprecators.each do |deprecator|
        assert_equal true, deprecator.silenced
        assert_equal [ActiveSupport::Deprecation::DEFAULT_BEHAVIORS[:silence]], deprecator.behavior
        assert_equal [ActiveSupport::Deprecation::DEFAULT_BEHAVIORS[:silence]], deprecator.disallowed_behavior
      end
    end

    test "ParamsWrapper is enabled in a new app and uses JSON as the format" do
      app "production"

      assert_equal [:json], ActionController::Base._wrapper_options.format
    end

    test "ParamsWrapper is enabled in an upgrade and uses JSON as the format" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.action_controller.wrap_parameters_by_default = true
      RUBY

      app "production"

      assert_equal [:json], ActionController::Base._wrapper_options.format
    end

    test "ParamsWrapper can be changed from the default in the initializer that was created prior to Rails 7" do
      app_file "config/initializers/wrap_parameters.rb", <<-RUBY
        ActiveSupport.on_load(:action_controller) do
          wrap_parameters format: [:xml]
        end
      RUBY

      app "production"

      assert_equal [:xml], ActionController::Base._wrapper_options.format
    end

    test "ParamsWrapper can be turned off" do
      add_to_config "Rails.application.config.action_controller.wrap_parameters_by_default = false"

      app "production"

      assert_equal [], ActionController::Base._wrapper_options.format
    end

    test "ActionController::Base.raise_on_missing_callback_actions is false by default for production" do
      app "production"

      assert_equal false, ActionController::Base.raise_on_missing_callback_actions
    end

    test "ActionController::Base.raise_on_missing_callback_actions is false by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal false, ActionController::Base.raise_on_missing_callback_actions
    end

    test "ActionController::Base.raise_on_missing_callback_actions can be configured in the new framework defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_2.rb", <<-RUBY
        Rails.application.config.action_controller.raise_on_missing_callback_actions = true
      RUBY

      app "production"

      assert_equal true, ActionController::Base.raise_on_missing_callback_actions
    end

    test "isolation_level is :thread by default" do
      app "development"
      assert_equal :thread, ActiveSupport::IsolatedExecutionState.isolation_level
    end

    test "isolation_level can be set in app config" do
      add_to_config "config.active_support.isolation_level = :fiber"

      app "development"
      assert_equal :fiber, ActiveSupport::IsolatedExecutionState.isolation_level
    end

    test "isolation_level can be set in initializer" do
      app_file "config/initializers/new_framework_defaults_7_0.rb", <<-RUBY
        Rails.application.config.active_support.isolation_level = :fiber
      RUBY

      app "development"
      assert_equal :fiber, ActiveSupport::IsolatedExecutionState.isolation_level
    end

    test "ActiveSupport::Cache.format_version is 7.1 by default for new apps" do
      app "development"

      assert_equal 7.1, ActiveSupport::Cache.format_version
    end

    test "ActiveSupport::Cache.format_version is 7.0 by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal 7.0, ActiveSupport::Cache.format_version
    end

    test "ActiveSupport::Cache.format_version can be configured via config.active_support.cache_format_version" do
      remove_from_config '.*config\.load_defaults.*\n'

      add_to_config "config.active_support.cache_format_version = 7.0"

      app "development"

      assert_equal 7.0, ActiveSupport::Cache.format_version
    end

    test "config.active_support.cache_format_version affects Rails.cache when set in an environment file (or earlier)" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/environments/development.rb", <<~RUBY
        Rails.application.config.active_support.cache_format_version = 7.0
      RUBY

      app "development"

      assert_not_nil Rails.cache.instance_variable_get(:@coder)
      assert_equal \
        Marshal.dump(ActiveSupport::Cache::NullStore.new.instance_variable_get(:@coder)),
        Marshal.dump(Rails.cache.instance_variable_get(:@coder))
    end

    test "raise_on_invalid_cache_expiration_time is false with 7.0 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_equal false, ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
    end

    test "raise_on_invalid_cache_expiration_time is true with 7.1 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.1"'
      app "development"

      assert_equal true, ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
    end

    test "raise_on_invalid_cache_expiration_time can be set via new framework defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app_file "config/initializers/new_framework_defaults_7_1.rb", <<-RUBY
        Rails.application.config.active_support.raise_on_invalid_cache_expiration_time = true
      RUBY
      app "development"

      assert_equal true, ActiveSupport::Cache::Store.raise_on_invalid_cache_expiration_time
    end

    test "adds a time zone aware type if using PostgreSQL" do
      original_configurations = ActiveRecord::Base.configurations
      ActiveRecord::Base.configurations = { production: { db1: { adapter: "postgresql" } } }
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY

      app "production"

      assert_equal [:datetime, :time, :timestamptz], ActiveRecord::Base.time_zone_aware_types
    ensure
      ActiveRecord::Base.configurations = original_configurations
    end

    test "doesn't add a time zone aware type if using MySQL" do
      original_configurations = ActiveRecord::Base.configurations
      ActiveRecord::Base.configurations = { production: { db1: { adapter: "mysql2" } } }
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "mysql2")
      RUBY

      app "production"

      assert_equal [:datetime, :time], ActiveRecord::Base.time_zone_aware_types
    ensure
      ActiveRecord::Base.configurations = original_configurations
    end

    test "can opt out of extra time zone aware types if using PostgreSQL" do
      original_configurations = ActiveRecord::Base.configurations
      ActiveRecord::Base.configurations = { production: { db1: { adapter: "postgresql" } } }
      app_file "config/initializers/active_record.rb", <<~RUBY
        ActiveRecord::Base.establish_connection(adapter: "postgresql")
      RUBY
      app_file "config/initializers/tz_aware_types.rb", <<~RUBY
        ActiveRecord::Base.time_zone_aware_types -= [:timestamptz]
      RUBY

      app "production"

      assert_equal [:datetime, :time], ActiveRecord::Base.time_zone_aware_types
    ensure
      ActiveRecord::Base.configurations = original_configurations
    end

    test "raise_on_missing_translations = true" do
      add_to_config "config.i18n.raise_on_missing_translations = true"
      app "development"

      assert_equal true, Rails.application.config.i18n.raise_on_missing_translations

      assert_raise(I18n::MissingTranslationData) do
        I18n.t("translations.missing")
      end
    end

    test "raise_on_missing_translations = false" do
      add_to_config "config.i18n.raise_on_missing_translations = false"
      app "development"

      assert_equal false, Rails.application.config.i18n.raise_on_missing_translations

      assert_nothing_raised do
        I18n.t("translations.missing")
      end
    end

    test "raise_on_missing_translations = true and custom exception handler in initializer" do
      add_to_config "config.i18n.raise_on_missing_translations = true"
      app_file "config/initializers/i18n.rb", <<~RUBY
        I18n.exception_handler = ->(exception, *) {
          if exception.is_a?(I18n::MissingTranslation)
            "handled I18n::MissingTranslation"
          else
            raise exception
          end
          }
      RUBY
      app "development"

      assert_equal true, Rails.application.config.i18n.raise_on_missing_translations

      assert_equal "handled I18n::MissingTranslation", I18n.t("translations.missing")
      assert_raise(I18n::InvalidLocale) do
        I18n.t("en.errors.messages.required", locale: "dsafdsafdsa")
      end
    end

    test "raise_on_missing_translations = false and custom exception handler in initializer" do
      add_to_config "config.i18n.raise_on_missing_translations = false"
      app_file "config/initializers/i18n.rb", <<~RUBY
        I18n.exception_handler = ->(exception, *) {
          if exception.is_a?(I18n::MissingTranslation)
            "handled I18n::MissingTranslation"
          else
            raise exception
          end
          }
      RUBY
      app "development"

      assert_equal false, Rails.application.config.i18n.raise_on_missing_translations

      assert_equal "handled I18n::MissingTranslation", I18n.t("translations.missing")
      assert_raise(I18n::InvalidLocale) do
        I18n.t("en.errors.messages.required", locale: "dsafdsafdsa")
      end
    end

    test "i18n custom exception handler in initializer and pluralization backend" do
      app_file "config/initializers/i18n.rb", <<~RUBY
        I18n.exception_handler = ->(exception, *) {
          if exception.is_a?(I18n::MissingTranslation)
            "handled I18n::MissingTranslation"
          else
            raise exception
          end
          }

        Rails.application.config.after_initialize do
          I18n.backend.class.include(I18n::Backend::Pluralization)
          I18n.backend.send(:init_translations)
          I18n.backend.store_translations :en, i18n: { plural: { rule: lambda { |n| [0, 1].include?(n) ? :one : :other } } }
          I18n.backend.store_translations :en, apples: { one: 'one or none', other: 'more than one' }
          I18n.backend.store_translations :en, pears: { pear: "pear", pears: "pears" }
        end
      RUBY

      app "development"

      assert I18n.backend.class.include?(I18n::Backend::Pluralization)
      assert_equal "one or none", I18n.t(:apples, count: 0)
      assert_raises I18n::InvalidPluralizationData do
        assert_equal "pears", I18n.t(:pears, count: 0)
      end
    end

    test "run_after_transaction_callbacks_in_order_defined is true in new apps" do
      app "development"

      assert_equal true, ActiveRecord.run_after_transaction_callbacks_in_order_defined
    end

    test "run_after_transaction_callbacks_in_order_defined is false in upgrading apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_equal false, ActiveRecord.run_after_transaction_callbacks_in_order_defined
    end

    test "run_after_transaction_callbacks_in_order_defined can be set via framework defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app_file "config/initializers/new_framework_defaults_7_1.rb", <<-RUBY
        Rails.application.config.active_record.run_after_transaction_callbacks_in_order_defined = true
      RUBY
      app "development"

      assert_equal true, ActiveRecord.run_after_transaction_callbacks_in_order_defined
    end

    test "run_after_transaction_callbacks_in_order_defined can be set via framework defaults even if Active Record was previously loaded" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app_file "config/initializers/01_configure_database.rb", <<-RUBY
        ActiveSupport.on_load(:active_record) do
          ActiveRecord::Base.connected?
        end
      RUBY
      app_file "config/initializers/new_framework_defaults_7_1.rb", <<-RUBY
        Rails.application.config.active_record.run_after_transaction_callbacks_in_order_defined = true
      RUBY
      app "development"

      assert_equal true, ActiveRecord.run_after_transaction_callbacks_in_order_defined
    end

    test "raises if configuration tries to assign to an actual method" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults = "7.0"'

      error = assert_raises(NoMethodError) do
        app "development"
      end

      assert_match(/Cannot assign to `load_defaults`, it is a configuration method/, error.message)
    end

    test "allows initializer to set active_record_encryption.configuration" do
      app_file "config/initializers/active_record_encryption.rb", <<-RUBY
        Rails.application.config.active_record.encryption.hash_digest_class = OpenSSL::Digest::SHA1
      RUBY

      app "development"

      assert_equal OpenSSL::Digest::SHA1, ActiveRecord::Encryption.config.hash_digest_class
    end

    test "sanitizer_vendor is set to best supported vendor in new apps" do
      app "development"

      assert_equal Rails::HTML::Sanitizer.best_supported_vendor, ActionView::Helpers::SanitizeHelper.sanitizer_vendor
    end

    test "sanitizer_vendor is set to HTML4 in upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_equal Rails::HTML4::Sanitizer, ActionView::Helpers::SanitizeHelper.sanitizer_vendor
    end

    test "sanitizer_vendor is set to a specific vendor" do
      add_to_config "config.action_view.sanitizer_vendor = ::MySanitizerVendor"
      app "development"

      assert_equal ::MySanitizerVendor, ActionView::Helpers::SanitizeHelper.sanitizer_vendor
    end

    test "Action Text uses the best supported safe list sanitizer in new apps" do
      app "development"

      require "action_view/base"

      assert_kind_of(
        Rails::HTML::Sanitizer.best_supported_vendor.safe_list_sanitizer,
        ActionText::ContentHelper.sanitizer,
      )
    end

    test "Action Text uses the HTML4 safe list sanitizer in upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_kind_of(
        Rails::HTML4::Sanitizer.safe_list_sanitizer,
        ActionText::ContentHelper.sanitizer,
      )
    end

    test "Action Text uses the specified vendor's safe list sanitizer" do
      add_to_config "config.action_text.sanitizer_vendor = ::MySanitizerVendor"

      app "development"

      require "action_view/base"

      assert_kind_of(
        ::MySafeListSanitizer,
        ActionText::ContentHelper.sanitizer,
      )
    end

    test "raise_on_missing_translations affects t in controllers and views" do
      add_to_config "config.i18n.raise_on_missing_translations = true"

      app_file "app/views/foo/view_test.html.erb", <<-RUBY
        <%=
          begin
            t("missing.translation")
          rescue I18n::MissingTranslationData
            "rescued missing translation error from view"
          end
        %>
      RUBY

      app_file "app/controllers/foo_controller.rb", <<-RUBY
      class FooController < ApplicationController
        layout false
        def controller_test
          response = begin
            t("missing.translation")
          rescue I18n::MissingTranslationData
            "rescued missing translation error from controller"
          end
          render plain: response
        end
        def view_test
          render "view_test"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          get "foo/controller" => "foo#controller_test"
          get "foo/view" => "foo#view_test"
        end
      RUBY

      app "development"

      get "foo/controller"
      assert_equal "rescued missing translation error from controller", last_response.body

      get "foo/view"
      assert_includes last_response.body, "rescued missing translation error from view"
    end

    test "raise_on_missing_translations = :strict affects human_attribute_name in model" do
      add_to_config "config.i18n.raise_on_missing_translations = :strict"

      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      app "development"

      assert_raises I18n::MissingTranslationData do
        Post.human_attribute_name("title")
      end
    end

    test "raise_on_missing_translations = true does not affect human_attribute_name in model" do
      add_to_config "config.i18n.raise_on_missing_translations = true"

      app_file "app/models/post.rb", <<-RUBY
        class Post < ActiveRecord::Base
        end
      RUBY

      app "development"

      assert_nothing_raised do
        Post.human_attribute_name("title")
      end
    end

    test "dom testing uses the HTML5 parser in new apps if it is supported" do
      app "development"
      expected = defined?(Nokogiri::HTML5) ? :html5 : :html4

      assert_equal(expected, Rails.application.config.dom_testing_default_html_version)
    end

    test "dom testing uses the HTML4 parser in upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "7.0"'
      app "development"

      assert_equal(:html4, Rails.application.config.dom_testing_default_html_version)
    end

    test "app attributes_for_inspect configuration takes precedence over default" do
      add_to_config "config.active_record.attributes_for_inspect = [:foo]"

      app "development"

      assert_equal [:foo], ActiveRecord::Base.attributes_for_inspect
    end

    test "model's attributes_for_inspect configuration takes precedence over default" do
      app_file "app/models/foo.rb", <<-RUBY
        class Foo < ApplicationRecord
          self.attributes_for_inspect = [:foo]
        end
      RUBY

      app "development"

      assert_equal [:foo], Foo.attributes_for_inspect
    end

    test "new Active Record connection adapters can be registered as aliases in application initializers" do
      app_file "config/database.yml", <<-YAML
        development:
          adapter: potato
          database: 'example_db'
      YAML

      app_file "config/initializers/active_record_connection_adapters.rb", <<-RUBY
        ActiveRecord::ConnectionAdapters.register(
          "potato",
          "ActiveRecord::ConnectionAdapters::SQLite3Adapter",
          "active_record/connection_adapters/sqlite3_adapter"
        )
      RUBY

      app "development"

      assert_equal "potato", ActiveRecord::Base.lease_connection.pool.db_config.adapter
      assert_equal "SQLite", ActiveRecord::Base.lease_connection.adapter_name
    end

    test "In development mode, config.active_record.query_log_tags_enabled is true by default" do
      restore_default_config

      app "development"

      assert Rails.application.config.active_record.query_log_tags_enabled
    end

    ["development", "production"].each do |env|
      test "active job adapter is async in #{env}" do
        app(env)
        assert_equal :async, Rails.application.config.active_job.queue_adapter
        adapter = ActiveJob::Base.queue_adapter
        assert_instance_of ActiveJob::QueueAdapters::AsyncAdapter, adapter
      end

      test "active job adapter can be overridden in #{env} via application.rb" do
        add_to_config "config.active_job.queue_adapter = :inline"
        app(env)
        assert_equal :inline, Rails.application.config.active_job.queue_adapter
        adapter = ActiveJob::Base.queue_adapter
        assert_instance_of ActiveJob::QueueAdapters::InlineAdapter, adapter
      end

      test "active job adapter can be overridden in #{env} via environment config" do
        app_file "config/environments/#{env}.rb", <<-RUBY
          Rails.application.configure do
            config.active_job.queue_adapter = :inline
          end
        RUBY
        app(env)
        assert_equal :inline, Rails.application.config.active_job.queue_adapter
        adapter = ActiveJob::Base.queue_adapter
        assert_instance_of ActiveJob::QueueAdapters::InlineAdapter, adapter
      end
    end

    test "active job adapter is `:test` in test environment" do
      app "test"
      assert_equal :test, Rails.application.config.active_job.queue_adapter
      adapter = ActiveJob::Base.queue_adapter
      assert_instance_of ActiveJob::QueueAdapters::TestAdapter, adapter
    end

    test "Regexp.timeout is set to 1s by default" do
      app "development"
      assert_equal 1, Regexp.timeout
    end

    test "Regexp.timeout can be configured" do
      add_to_config "Regexp.timeout = 5"
      app "development"
      assert_equal 5, Regexp.timeout
    end

    test "action_controller.logger defaults to Rails.logger" do
      restore_default_config
      add_to_config "config.logger = Logger.new(STDOUT, level: Logger::INFO)"
      app "development"

      output = capture(:stdout) do
        get "/"
      end

      assert_equal Rails.logger, Rails.application.config.action_controller.logger
      assert output.include?("Processing by Rails::WelcomeController#index as HTML")
    end

    test "action_controller.logger can be disabled by assigning nil" do
      add_to_config <<-RUBY
        config.logger = Logger.new(STDOUT, level: Logger::INFO)
        config.action_controller.logger = nil
      RUBY
      app "development"

      output = capture(:stdout) do
        get "/"
      end

      assert_nil Rails.application.config.action_controller.logger
      assert_not output.include?("Processing by Rails::WelcomeController#index as HTML")
    end

    test "action_controller.logger can be disabled by assigning false" do
      add_to_config <<-RUBY
        config.logger = Logger.new(STDOUT, level: Logger::INFO)
        config.action_controller.logger = false
      RUBY

      app "development"
      output = capture(:stdout) do
        get "/"
      end


      assert_equal false, Rails.application.config.action_controller.logger
      assert_not output.include?("Processing by Rails::WelcomeController#index as HTML")
    end

    test "config.action_controller.live_streaming_excluded_keys configures ActionController::Live" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
      class PostsController < ActionController::Base
        include ActionController::Live

        def index
          render plain: self.class.live_streaming_excluded_keys.inspect
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.live_streaming_excluded_keys = [:active_record_connected_to_stack, :custom_key]
      RUBY

      app "development"

      get "/posts"
      assert_equal "[:active_record_connected_to_stack, :custom_key]", last_response.body
    end

    private
      def set_custom_config(contents, config_source = "custom".inspect)
        app_file "config/custom.yml", contents

        add_to_config <<~RUBY
          config.my_custom_config = config_for(#{config_source})
        RUBY
      end
  end
end
