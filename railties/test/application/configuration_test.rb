# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "env_helpers"
require "set"

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

    def app(env = "development")
      @app ||= begin
        ENV["RAILS_ENV"] = env

        require "#{app_path}/config/environment"

        Rails.application
      ensure
        ENV.delete "RAILS_ENV"
      end
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
      build_app(initializers: true)
      add_to_env_config "production", "config.cache_store = Class.new {}.new"
      add_to_env_config "production", "config.active_record.cache_versioning = true"

      error = assert_raise(RuntimeError) do
        app "production"
      end

      assert_match(/You're using a cache/, error.message)
    end

    test "a renders exception on pending migration" do
      add_to_config <<-RUBY
        config.active_record.migration_error    = :page_load
        config.consider_all_requests_local      = true
        config.action_dispatch.show_exceptions  = true
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

    test "Rails.groups returns available groups" do
      require "rails"

      Rails.env = "development"
      assert_equal [:default, "development"], Rails.groups
      assert_equal [:default, "development", :assets], Rails.groups(assets: [:development])
      assert_equal [:default, "development", :another, :assets], Rails.groups(:another, assets: %w(development))

      Rails.env = "test"
      assert_equal [:default, "test"], Rails.groups(assets: [:development])

      ENV["RAILS_GROUPS"] = "javascripts,stylesheets"
      assert_equal [:default, "test", "javascripts", "stylesheets"], Rails.groups
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

    test "does not eager load controller actions in development" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index;end
          def show;end
        end
      RUBY

      app "development"

      assert_nil PostsController.instance_variable_get(:@action_methods)
    end

    test "eager loads controller actions in production" do
      app_file "app/controllers/posts_controller.rb", <<-RUBY
        class PostsController < ActionController::Base
          def index;end
          def show;end
        end
      RUBY

      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app "production"

      assert_equal %w(index show).to_set, PostsController.instance_variable_get(:@action_methods)
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
        config.eager_load = true
        config.cache_classes = true
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
        ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
        ActiveRecord::Migration.verbose = false
        ActiveRecord::Schema.define(version: 1) do
          create_table :posts do |t|
            t.string :title
          end
        end
      RUBY

      app "development"

      assert_not_includes Post.instance_methods, :title
    end

    test "does not eager load attribute methods in production when the schema cache is empty" do
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
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app "production"

      assert_not_includes Post.instance_methods, :title
    end

    test "eager loads attribute methods in production when the schema cache is populated" do
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
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app_file "config/initializers/schema_cache.rb", <<-RUBY
        ActiveRecord::Base.connection.schema_cache.add("posts")
      RUBY

      app "production"

      assert_includes Post.instance_methods, :title
    end

    test "does not attempt to eager load attribute methods for models that aren't connected" do
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
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app_file "app/models/comment.rb", <<-RUBY
        class Comment < ActiveRecord::Base
          establish_connection(adapter: "mysql2", database: "does_not_exist")
        end
      RUBY

      assert_nothing_raised do
        app "production"
      end
    end

    test "initialize an eager loaded, cache classes app" do
      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app "development"

      assert_equal :require, ActiveSupport::Dependencies.mechanism
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
        config.eager_load = true
        config.cache_classes = true
      RUBY

      use_frameworks []

      assert_nothing_raised do
        app "development"
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters" do
      add_to_config <<-RUBY
        config.filter_parameters += [ :foo, 'bar', lambda { |key, value|
          value = value.reverse if /baz/.match?(key)
        }]
      RUBY

      assert_nothing_raised do
        app "development"
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters in an initializer" do
      app_file "config/initializers/filter_parameters_logging.rb", <<-RUBY
        Rails.application.config.filter_parameters += [ :password, :foo, 'bar' ]
      RUBY

      app "development"

      assert_equal [:password, :foo, "bar"], Rails.application.env_config["action_dispatch.parameter_filter"]
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

    test "config.paths.public sets Rails.public_path" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      app "development"
      assert_equal Pathname.new(app_path).join("somewhere"), Rails.public_path
    end

    test "In production mode, config.public_file_server.enabled is off by default" do
      restore_default_config

      with_rails_env "production" do
        app "production"
        assert_not app.config.public_file_server.enabled
      end
    end

    test "In production mode, config.public_file_server.enabled is enabled when RAILS_SERVE_STATIC_FILES is set" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_SERVE_STATIC_FILES", "1" do
          app "production"
          assert app.config.public_file_server.enabled
        end
      end
    end

    test "In production mode, STDOUT logging is enabled when RAILS_LOG_TO_STDOUT is set" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_LOG_TO_STDOUT", "1" do
          app "production"
          assert ActiveSupport::Logger.logger_outputs_to?(app.config.logger, STDOUT)
        end
      end
    end

    test "In production mode, config.public_file_server.enabled is disabled when RAILS_SERVE_STATIC_FILES is blank" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_SERVE_STATIC_FILES", " " do
          app "production"
          assert_not app.config.public_file_server.enabled
        end
      end
    end

    test "Use key_generator when secret_key_base is set" do
      make_basic_app do |application|
        application.secrets.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"
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
        application.secrets.secret_key_base = "b3c631c314c0bbca50c1b2843150fe33"
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
        Rails.application.credentials.secret_key_base = nil
      RUBY

      # For test that works even if tmp dir does not exist.
      Dir.chdir(app_path) { FileUtils.remove_dir("tmp") }

      app "development"

      assert_not_nil app.secrets.secret_key_base
      assert File.exist?(app_path("tmp/development_secret.txt"))
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

    test "raise when secret_key_base is not a type of string" do
      add_to_config <<-RUBY
        Rails.application.credentials.secret_key_base = 123
      RUBY

      assert_raise(ArgumentError) do
        app "production"
      end
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

    test "secrets.secret_key_base is used when config/secrets.yml is present" do
      app_file "config/secrets.yml", <<-YAML
        development:
          secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
      YAML

      app "development"
      assert_equal "3b7cd727ee24e8444053437c36cc66c3", app.secrets.secret_key_base
      assert_equal "3b7cd727ee24e8444053437c36cc66c3", app.secret_key_base
    end

    test "secret_key_base is copied from config to secrets when not set" do
      remove_file "config/secrets.yml"
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = "3b7cd727ee24e8444053437c36cc66c3"
      RUBY

      app "development"
      assert_equal "3b7cd727ee24e8444053437c36cc66c3", app.secrets.secret_key_base
    end

    test "custom secrets saved in config/secrets.yml are loaded in app secrets" do
      app_file "config/secrets.yml", <<-YAML
        development:
          secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
          aws_access_key_id: myamazonaccesskeyid
          aws_secret_access_key: myamazonsecretaccesskey
      YAML

      app "development"

      assert_equal "myamazonaccesskeyid", app.secrets.aws_access_key_id
      assert_equal "myamazonsecretaccesskey", app.secrets.aws_secret_access_key
    end

    test "shared secrets saved in config/secrets.yml are loaded in app secrets" do
      app_file "config/secrets.yml", <<-YAML
        shared:
          api_key: 3b7cd727
      YAML

      app "development"

      assert_equal "3b7cd727", app.secrets.api_key
    end

    test "shared secrets will yield to environment specific secrets" do
      app_file "config/secrets.yml", <<-YAML
        shared:
          api_key: 3b7cd727

        development:
          api_key: abc12345
      YAML

      app "development"

      assert_equal "abc12345", app.secrets.api_key
    end

    test "blank config/secrets.yml does not crash the loading process" do
      app_file "config/secrets.yml", <<-YAML
      YAML

      app "development"

      assert_nil app.secrets.not_defined
    end

    test "config.secret_key_base over-writes a blank secrets.secret_key_base" do
      app_file "config/initializers/secret_token.rb", <<-RUBY
        Rails.application.config.secret_key_base = "iaminallyoursecretkeybase"
      RUBY
      app_file "config/secrets.yml", <<-YAML
        development:
          secret_key_base:
      YAML

      app "development"

      assert_equal "iaminallyoursecretkeybase", app.secrets.secret_key_base
    end

    test "that nested keys are symbolized the same as parents for hashes more than one level deep" do
      app_file "config/secrets.yml", <<-YAML
        development:
          smtp_settings:
            address: "smtp.example.com"
            user_name: "postmaster@example.com"
            password: "697361616320736c6f616e2028656c6f7265737429"
      YAML

      app "development"

      assert_equal "697361616320736c6f616e2028656c6f7265737429", app.secrets.smtp_settings[:password]
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
      assert_match(/csrf\-param/, last_response.body)
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

    test "allows setting the queue name for the ActionMailer::DeliveryJob" do
      add_to_config <<-RUBY
        config.action_mailer.deliver_later_queue_name = 'test_default'
      RUBY

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal "test_default", ActionMailer::Base.class_variable_get(:@@deliver_later_queue_name)
    end

    test "ActionMailer::DeliveryJob queue name is :mailers without the Rails defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_equal :mailers, ActionMailer::Base.class_variable_get(:@@deliver_later_queue_name)
    end

    test "ActionMailer::DeliveryJob queue name is nil by default in 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.1"'

      app "development"

      require "mail"
      _ = ActionMailer::Base

      assert_nil ActionMailer::Base.class_variable_get(:@@deliver_later_queue_name)
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

      config = Rails.application.config
      assert Rails.autoloaders.zeitwerk_enabled?
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.main
      assert_equal "rails.main", Rails.autoloaders.main.tag
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.once
      assert_equal "rails.once", Rails.autoloaders.once.tag
      assert_equal [Rails.autoloaders.main, Rails.autoloaders.once], Rails.autoloaders.to_a
      assert_equal ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector, Rails.autoloaders.main.inflector
      assert_equal ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector, Rails.autoloaders.once.inflector

      config.autoloader = :classic
      assert_not Rails.autoloaders.zeitwerk_enabled?
      assert_nil Rails.autoloaders.main
      assert_nil Rails.autoloaders.once
      assert_equal 0, Rails.autoloaders.count

      config.autoloader = :zeitwerk
      assert Rails.autoloaders.zeitwerk_enabled?
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.main
      assert_equal "rails.main", Rails.autoloaders.main.tag
      assert_instance_of Zeitwerk::Loader, Rails.autoloaders.once
      assert_equal "rails.once", Rails.autoloaders.once.tag
      assert_equal [Rails.autoloaders.main, Rails.autoloaders.once], Rails.autoloaders.to_a
      assert_equal ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector, Rails.autoloaders.main.inflector
      assert_equal ActiveSupport::Dependencies::ZeitwerkIntegration::Inflector, Rails.autoloaders.once.inflector

      assert_raises(ArgumentError) { config.autoloader = :unknown }
    end

    test "config.action_view.cache_template_loading with cache_classes default" do
      add_to_config "config.cache_classes = true"

      app "development"
      require "action_view/base"

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading without cache_classes default" do
      add_to_config "config.cache_classes = false"

      app "development"
      require "action_view/base"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = false" do
      add_to_config <<-RUBY
        config.cache_classes = true
        config.action_view.cache_template_loading = false
      RUBY

      app "development"
      require "action_view/base"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = true" do
      add_to_config <<-RUBY
        config.cache_classes = false
        config.action_view.cache_template_loading = true
      RUBY

      app "development"
      require "action_view/base"

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading with cache_classes in an environment" do
      build_app(initializers: true)
      add_to_env_config "development", "config.cache_classes = false"

      # These requires are to emulate an engine loading Action View before the application
      require "action_view"
      require "action_view/railtie"
      require "action_view/base"

      app "development"

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_dispatch.show_exceptions is sent in env" do
      make_basic_app do |application|
        application.config.action_dispatch.show_exceptions = true
      end

      class ::OmgController < ActionController::Base
        def index
          render plain: request.env["action_dispatch.show_exceptions"]
        end
      end

      get "/"
      assert_equal "true", last_response.body
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
      assert_equal '#<ActionController::Parameters {"title"=>"foo"} permitted: false>', last_response.body
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
          render plain: params.require(:post).permit(:name)
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

      assert_equal true, ActionController::Base.default_protect_from_forgery
      assert_includes ActionController::Base.__callbacks[:process_action].map(&:filter), :verify_authenticity_token
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

    test "config.session_store with :active_record_store with activerecord-session_store gem" do
      make_basic_app do |application|
        ActionDispatch::Session::ActiveRecordStore = Class.new(ActionDispatch::Session::CookieStore)
        application.config.session_store :active_record_store
      end
    ensure
      ActionDispatch::Session.send :remove_const, :ActiveRecordStore
    end

    test "config.session_store with :active_record_store without activerecord-session_store gem" do
      e = assert_raise RuntimeError do
        make_basic_app do |application|
          application.config.session_store :active_record_store
        end
      end
      assert_match(/activerecord-session_store/, e.message)
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
      assert_equal session_options, app.config.session_options
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

    test "config.log_level with custom logger" do
      make_basic_app do |application|
        application.config.logger = Logger.new(STDOUT)
        application.config.log_level = :debug
      end
      assert_equal Logger::DEBUG, Rails.logger.level
    end

    test "respond_to? accepts include_private" do
      make_basic_app

      assert_not_respond_to Rails.configuration, :method_missing
      assert Rails.configuration.respond_to?(:method_missing, true)
    end

    test "config.active_record.dump_schema_after_migration is false on production" do
      build_app

      app "production"

      assert_not ActiveRecord::Base.dump_schema_after_migration
    end

    test "config.active_record.dump_schema_after_migration is true by default in development" do
      app "development"

      assert ActiveRecord::Base.dump_schema_after_migration
    end

    test "config.active_record.verbose_query_logs is false by default in development" do
      app "development"

      assert_not ActiveRecord::Base.verbose_query_logs
    end

    test "config.active_record.suppress_multiple_database_warning is false by default in development" do
      app "development"
      assert_not ActiveRecord::Base.suppress_multiple_database_warning
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

    test "autoload paths will exclude the configured javascript_path" do
      add_to_config "config.javascript_path = 'webpack'"
      app_dir("app/webpack")

      app "development"

      ActiveSupport::Dependencies.autoload_paths.each do |path|
        assert_not_operator path, :end_with?, "app/assets"
        assert_not_operator path, :end_with?, "app/webpack"
      end
    end

    test "autoload paths are added to $LOAD_PATH by default" do
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

    test "autoload paths are not added to $LOAD_PATH if opted-out" do
      add_to_config "config.add_autoload_paths_to_load_path = false"
      app "development"

      assert_empty ActiveSupport::Dependencies.autoload_paths & $LOAD_PATH

      # Precondition, ensure we are testing something next.
      assert_not_empty Rails.configuration.paths.load_paths
      assert_empty Rails.configuration.paths.load_paths - $LOAD_PATH
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

      assert_includes $LOAD_PATH, "#{app_path}/custom_autoload_path"
      assert_includes $LOAD_PATH, "#{app_path}/custom_autoload_once_path"
      assert_includes $LOAD_PATH, "#{app_path}/custom_eager_load_path"
    end

    test "autoloading during initialization gets deprecation message and clearing if config.cache_classes is false" do
      app_file "lib/c.rb", <<~EOS
        class C
          extend ActiveSupport::DescendantsTracker
        end

        class X < C
        end
      EOS

      app_file "app/models/d.rb", <<~EOS
        require "c"

        class D < C
        end
      EOS

      app_file "config/initializers/autoload.rb", "D.class"

      app "development"

      # TODO: Test deprecation message, assert_depcrecated { app "development" }
      # does not collect it.

      assert_equal [X], C.descendants
      assert_empty ActiveSupport::Dependencies.autoloaded_constants
    end

    test "autoloading during initialization triggers nothing if config.cache_classes is true" do
      app_file "lib/c.rb", <<~EOS
        class C
          extend ActiveSupport::DescendantsTracker
        end

        class X < C
        end
      EOS

      app_file "app/models/d.rb", <<~EOS
        require "c"

        class D < C
        end
      EOS

      app_file "config/initializers/autoload.rb", "D.class"

      app "production"

      # TODO: Test no deprecation message is issued.

      assert_equal [X, D], C.descendants
    end

    test "load_database_yaml returns blank hash if configuration file is blank" do
      app_file "config/database.yml", ""
      app "development"
      assert_equal({}, Rails.application.config.load_database_yaml)
    end

    test "setup_initial_database_yaml does not print a warning if config.active_record.suppress_multiple_database_warning is true" do
      app_file "config/database.yml", <<-YAML
        <%= Rails.env %>:
          username: bobby
          adapter: sqlite3
          database: 'dev_db'
      YAML
      add_to_config <<-RUBY
        config.active_record.suppress_multiple_database_warning = true
      RUBY
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

    test "config_for loads custom configuration from yaml accessible as symbol or string" do
      set_custom_config <<~RUBY
        development:
          foo: "bar"
      RUBY

      app "development"

      assert_equal "bar", Rails.application.config.my_custom_config[:foo]
      assert_equal "bar", Rails.application.config.my_custom_config["foo"]
    end

    test "config_for loads nested custom configuration from yaml as symbol keys" do
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
      set_custom_config <<~RUBY
        development:
          key: <%= 'custom key' %>
      RUBY

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

    test "ActiveSupport::Digest.hash_digest_class is Digest::SHA1 by default for new apps" do
      app "development"

      assert_equal Digest::SHA1, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::Digest.hash_digest_class is Digest::MD5 by default for upgraded apps" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"

      assert_equal Digest::MD5, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::Digest.hash_digest_class can be configured via config.active_support.use_sha1_digests" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_0.rb", <<-RUBY
        Rails.application.config.active_support.use_sha1_digests = true
      RUBY

      app "development"

      assert_equal Digest::SHA1, ActiveSupport::Digest.hash_digest_class
    end

    test "ActiveSupport::Digest.hash_digest_class can be configured via config.active_support.hash_digest_class" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/custom_digest_class.rb", <<-RUBY
        Rails.application.config.active_support.hash_digest_class = Digest::SHA256
      RUBY

      app "development"

      assert_equal Digest::SHA256, ActiveSupport::Digest.hash_digest_class
    end

    test "custom serializers should be able to set via config.active_job.custom_serializers in an initializer" do
      class ::DummySerializer < ActiveJob::Serializers::ObjectSerializer; end

      app_file "config/initializers/custom_serializers.rb", <<-RUBY
      Rails.application.config.active_job.custom_serializers << DummySerializer
      RUBY

      app "development"

      assert_includes ActiveJob::Serializers.serializers, DummySerializer
    end

    test "active record job queue is set" do
      app "development"

      assert_equal ActiveSupport::InheritableOptions.new(destroy: :active_record_destroy), ActiveRecord::Base.queues
    end

    test "destroy association async job should be loaded in configs" do
      app "development"

      assert_equal ActiveRecord::DestroyAssociationAsyncJob, ActiveRecord::Base.destroy_association_async_job
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

    test "ActionView::Helpers::AssetTagHelper.preload_links_header is true by default" do
      app "development"
      assert_equal true, ActionView::Helpers::AssetTagHelper.preload_links_header
    end

    test "ActionView::Helpers::AssetTagHelper.preload_links_header is nil by default in an application being upgraded" do
      remove_from_config '.*config\.load_defaults.*\n'

      app "development"
      assert_nil ActionView::Helpers::AssetTagHelper.preload_links_header
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

    test "stylesheet_link_tag sets the Link header by default" do
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
      assert_match %r[<link rel="stylesheet" media="screen" href="/application.css" />], last_response.body
      assert_equal "</application.css>; rel=preload; as=style; nopush", last_response.headers["Link"]
    end

    test "stylesheet_link_tag doesn't set the Link header when disabled" do
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
      assert_match %r[<link rel="stylesheet" media="screen" href="/application.css" />], last_response.body
      assert_nil last_response.headers["Link"]
    end

    test "stylesheet_link_tag doesn't set the Link header in an application being upgraded" do
      remove_from_config '.*config\.load_defaults.*\n'

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
      assert_match %r[<link rel="stylesheet" media="screen" href="/application.css" />], last_response.body
      assert_nil last_response.headers["Link"]
    end

    test "javascript_include_tag sets the Link header by default" do
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
      assert_equal "</application.js>; rel=preload; as=script; nopush", last_response.headers["Link"]
    end

    test "javascript_include_tag doesn't set the Link header in an application being upgraded" do
      remove_from_config '.*config\.load_defaults.*\n'

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
      assert_nil last_response.headers["Link"]
    end

    test "javascript_include_tag doesn't set the Link header when disabled" do
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
      assert_nil last_response.headers["Link"]
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

    test "ActiveJob::Base.skip_after_callbacks_if_terminated is true by default" do
      app "development"

      assert_equal true, ActiveJob::Base.skip_after_callbacks_if_terminated
    end

    test "ActiveJob::Base.skip_after_callbacks_if_terminated is false in the 6.0 defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_equal false, ActiveJob::Base.skip_after_callbacks_if_terminated
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

    test "ActionMailer::Base.delivery_job is ActionMailer::MailDeliveryJob by default" do
      app "development"

      assert_equal ActionMailer::MailDeliveryJob, ActionMailer::Base.delivery_job
    end

    test "ActionMailer::Base.delivery_job is ActionMailer::DeliveryJob in the 5.x defaults" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "5.2"'

      app "development"

      assert_equal ActionMailer::DeliveryJob, ActionMailer::Base.delivery_job
    end

    test "ActionMailer::Base.delivery_job can be configured in the new framework defaults" do
      remove_from_config '.*config\.load_defaults.*\n'

      app_file "config/initializers/new_framework_defaults_6_0.rb", <<-RUBY
        Rails.application.config.action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"
      RUBY

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

    test "hosts include .localhost in development" do
      app "development"
      assert_includes Rails.application.config.hosts, ".localhost"
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

    test "unknown_asset_fallback is false by default" do
      app "development"

      assert_equal false, Rails.application.config.assets.unknown_asset_fallback
    end

    test "legacy_connection_handling is false by default for new apps" do
      app "development"

      assert_equal false, Rails.application.config.active_record.legacy_connection_handling
    end

    test "legacy_connection_handling is not set before 6.1" do
      remove_from_config '.*config\.load_defaults.*\n'
      add_to_config 'config.load_defaults "6.0"'

      app "development"

      assert_nil Rails.application.config.active_record.legacy_connection_handling
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
