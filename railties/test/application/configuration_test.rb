require "isolation/abstract_unit"
require 'rack/test'
require 'env_helpers'

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

    def app(env = 'development')
      @app ||= begin
        ENV['RAILS_ENV'] = env

        # FIXME: shush Sass warning spam, not relevant to testing Railties
        Kernel.silence_warnings do
          require "#{app_path}/config/environment"
        end

        Rails.application
      ensure
        ENV.delete 'RAILS_ENV'
      end
    end

    def setup
      build_app
      supress_default_config
    end

    def teardown
      teardown_app
      FileUtils.rm_rf(new_app) if File.directory?(new_app)
    end

    def supress_default_config
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
        assert_nil ENV['RAILS_ENV']
      end
    end

    test "By default logs tags are not set in development" do
      restore_default_config

      with_rails_env "development" do
        app 'development'
        assert Rails.application.config.log_tags.blank?
      end
    end

    test "By default logs are tagged with :request_id in production" do
      restore_default_config

      with_rails_env "production" do
        app 'production'
        assert_equal [:request_id], Rails.application.config.log_tags
      end
    end

    test "lib dir is on LOAD_PATH during config" do
      app_file 'lib/my_logger.rb', <<-RUBY
        require "logger"
        class MyLogger < ::Logger
        end
      RUBY
      add_to_top_of_config <<-RUBY
        require 'my_logger'
        config.logger = MyLogger.new STDOUT
      RUBY

      app 'development'

      assert_equal 'MyLogger', Rails.application.config.logger.class.name
    end

    test "a renders exception on pending migration" do
      add_to_config <<-RUBY
        config.active_record.migration_error    = :page_load
        config.consider_all_requests_local      = true
        config.action_dispatch.show_exceptions  = true
      RUBY

      app_file 'db/migrate/20140708012246_create_user.rb', <<-RUBY
        class CreateUser < ActiveRecord::Migration::Current
          def change
            create_table :users
          end
        end
      RUBY

      app 'development'

      ActiveRecord::Migrator.migrations_paths = ["#{app_path}/db/migrate"]

      begin
        get "/foo"
        assert_equal 500, last_response.status
        assert_match "ActiveRecord::PendingMigrationError", last_response.body
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
      require 'rails'
      assert_nil Rails.application
      app 'development'
      assert_equal AppTemplate::Application.instance, Rails.application
    end

    test "Rails.application responds to all instance methods" do
      app 'development'
      assert_respond_to Rails.application, :routes_reloader
      assert_equal Rails.application.routes_reloader, AppTemplate::Application.routes_reloader
    end

    test "Rails::Application responds to paths" do
      app 'development'
      assert_respond_to AppTemplate::Application, :paths
      assert_equal ["#{app_path}/app/views"], AppTemplate::Application.paths["app/views"].expanded
    end

    test "the application root is set correctly" do
      app 'development'
      assert_equal Pathname.new(app_path), Rails.application.root
    end

    test "the application root can be seen from the application singleton" do
      app 'development'
      assert_equal Pathname.new(app_path), AppTemplate::Application.root
    end

    test "the application root can be set" do
      copy_app
      add_to_config <<-RUBY
        config.root = '#{new_app}'
      RUBY

      use_frameworks []

      app 'development'

      assert_equal Pathname.new(new_app), Rails.application.root
    end

    test "the application root is Dir.pwd if there is no config.ru" do
      File.delete("#{app_path}/config.ru")

      use_frameworks []

      Dir.chdir("#{app_path}") do
        app 'development'
        assert_equal Pathname.new("#{app_path}"), Rails.application.root
      end
    end

    test "Rails.root should be a Pathname" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      app 'development'

      assert_instance_of Pathname, Rails.root
    end

    test "Rails.public_path should be a Pathname" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      app 'development'

      assert_instance_of Pathname, Rails.public_path
    end

    test "initialize an eager loaded, cache classes app" do
      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      app 'development'

      assert_equal :require, ActiveSupport::Dependencies.mechanism
    end

    test "application is always added to eager_load namespaces" do
      app 'development'
      assert_includes Rails.application.config.eager_load_namespaces, AppTemplate::Application
    end

    test "the application can be eager loaded even when there are no frameworks" do
      FileUtils.rm_rf("#{app_path}/app/models/application_record.rb")
      FileUtils.rm_rf("#{app_path}/app/mailers/application_mailer.rb")
      FileUtils.rm_rf("#{app_path}/config/environments")
      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      use_frameworks []

      assert_nothing_raised do
        app 'development'
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters" do
      add_to_config <<-RUBY
        config.filter_parameters += [ :foo, 'bar', lambda { |key, value|
          value = value.reverse if key =~ /baz/
        }]
      RUBY

      assert_nothing_raised do
        app 'development'
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters in an initializer" do
      app_file 'config/initializers/filter_parameters_logging.rb', <<-RUBY
        Rails.application.config.filter_parameters += [ :password, :foo, 'bar' ]
      RUBY

      app 'development'

      assert_equal [:password, :foo, 'bar'], Rails.application.env_config['action_dispatch.parameter_filter']
    end

    test "config.to_prepare is forwarded to ActionDispatch" do
      $prepared = false

      add_to_config <<-RUBY
        config.to_prepare do
          $prepared = true
        end
      RUBY

      assert !$prepared

      app 'development'

      get "/"
      assert $prepared
    end

    def assert_utf8
      assert_equal Encoding::UTF_8, Encoding.default_external
      assert_equal Encoding::UTF_8, Encoding.default_internal
    end

    test "skipping config.encoding still results in 'utf-8' as the default" do
      app 'development'
      assert_utf8
    end

    test "config.encoding sets the default encoding" do
      add_to_config <<-RUBY
        config.encoding = "utf-8"
      RUBY

      app 'development'
      assert_utf8
    end

    test "config.paths.public sets Rails.public_path" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      app 'development'
      assert_equal Pathname.new(app_path).join("somewhere"), Rails.public_path
    end

    test "In production mode, config.public_file_server.enabled is off by default" do
      restore_default_config

      with_rails_env "production" do
        app 'production'
        assert_not app.config.public_file_server.enabled
      end
    end

    test "In production mode, config.public_file_server.enabled is enabled when RAILS_SERVE_STATIC_FILES is set" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_SERVE_STATIC_FILES", "1" do
          app 'production'
          assert app.config.public_file_server.enabled
        end
      end
    end

    test "In production mode, STDOUT logging is enabled when RAILS_LOG_TO_STDOUT is set" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_LOG_TO_STDOUT", "1" do
          app 'production'
          assert ActiveSupport::Logger.logger_outputs_to?(app.config.logger, STDOUT)
        end
      end
    end

    test "In production mode, config.public_file_server.enabled is disabled when RAILS_SERVE_STATIC_FILES is blank" do
      restore_default_config

      with_rails_env "production" do
        switch_env "RAILS_SERVE_STATIC_FILES", " " do
          app 'production'
          assert_not app.config.public_file_server.enabled
        end
      end
    end

    test "config.serve_static_files is deprecated" do
      make_basic_app do |application|
        assert_deprecated do
          application.config.serve_static_files = true
        end

        assert application.config.public_file_server.enabled
      end
    end

    test "config.static_cache_control is deprecated" do
      make_basic_app do |application|
        assert_deprecated do
          application.config.static_cache_control = "public, max-age=60"
        end

        assert_equal application.config.static_cache_control, "public, max-age=60"
      end
    end

    test "Use key_generator when secret_key_base is set" do
      make_basic_app do |application|
        application.secrets.secret_key_base = 'b3c631c314c0bbca50c1b2843150fe33'
        application.config.session_store :disabled
      end

      class ::OmgController < ActionController::Base
        def index
          cookies.signed[:some_key] = "some_value"
          render text: cookies[:some_key]
        end
      end

      get "/"

      secret = app.key_generator.generate_key('signed cookie')
      verifier = ActiveSupport::MessageVerifier.new(secret)
      assert_equal 'some_value', verifier.verify(last_response.body)
    end

    test "application verifier can be used in the entire application" do
      make_basic_app do |application|
        application.secrets.secret_key_base = 'b3c631c314c0bbca50c1b2843150fe33'
        application.config.session_store :disabled
      end

      message = app.message_verifier(:sensitive_value).generate("some_value")

      assert_equal 'some_value', Rails.application.message_verifier(:sensitive_value).verify(message)

      secret = app.key_generator.generate_key('sensitive_value')
      verifier = ActiveSupport::MessageVerifier.new(secret)
      assert_equal 'some_value', verifier.verify(message)
    end

    test "application message verifier can be used when the key_generator is ActiveSupport::LegacyKeyGenerator" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = "b3c631c314c0bbca50c1b2843150fe33"
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
      YAML

      app 'development'

      assert_equal app.env_config['action_dispatch.key_generator'], Rails.application.key_generator
      assert_equal app.env_config['action_dispatch.key_generator'].class, ActiveSupport::LegacyKeyGenerator
      message = app.message_verifier(:sensitive_value).generate("some_value")
      assert_equal 'some_value', Rails.application.message_verifier(:sensitive_value).verify(message)
    end

    test "warns when secrets.secret_key_base is blank and config.secret_token is set" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = "b3c631c314c0bbca50c1b2843150fe33"
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
      YAML

      app 'development'

      assert_deprecated(/You didn't set `secret_key_base`./) do
        app.env_config
      end
    end

    test "raise when secrets.secret_key_base is not a type of string" do
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base: 123
      YAML

      app 'development'

      assert_raise(ArgumentError) do
        app.key_generator
      end
    end

    test "prefer secrets.secret_token over config.secret_token" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = ""
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_token: 3b7cd727ee24e8444053437c36cc66c3
      YAML

      app 'development'

      assert_equal '3b7cd727ee24e8444053437c36cc66c3', app.secrets.secret_token
    end

    test "application verifier can build different verifiers" do
      make_basic_app do |application|
        application.secrets.secret_key_base = 'b3c631c314c0bbca50c1b2843150fe33'
        application.config.session_store :disabled
      end

      default_verifier = app.message_verifier(:sensitive_value)
      text_verifier = app.message_verifier(:text)

      message = text_verifier.generate('some_value')

      assert_equal 'some_value', text_verifier.verify(message)
      assert_raises ActiveSupport::MessageVerifier::InvalidSignature do
        default_verifier.verify(message)
      end

      assert_equal default_verifier.object_id, app.message_verifier(:sensitive_value).object_id
      assert_not_equal default_verifier.object_id, text_verifier.object_id
    end

    test "secrets.secret_key_base is used when config/secrets.yml is present" do
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
      YAML

      app 'development'
      assert_equal '3b7cd727ee24e8444053437c36cc66c3', app.secrets.secret_key_base
    end

    test "secret_key_base is copied from config to secrets when not set" do
      remove_file "config/secrets.yml"
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_key_base = "3b7cd727ee24e8444053437c36cc66c3"
      RUBY

      app 'development'
      assert_equal '3b7cd727ee24e8444053437c36cc66c3', app.secrets.secret_key_base
    end

    test "config.secret_token over-writes a blank secrets.secret_token" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = "b3c631c314c0bbca50c1b2843150fe33"
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
          secret_token:
      YAML

      app 'development'

      assert_equal 'b3c631c314c0bbca50c1b2843150fe33', app.secrets.secret_token
      assert_equal 'b3c631c314c0bbca50c1b2843150fe33', app.config.secret_token
    end

    test "custom secrets saved in config/secrets.yml are loaded in app secrets" do
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
          aws_access_key_id: myamazonaccesskeyid
          aws_secret_access_key: myamazonsecretaccesskey
      YAML

      app 'development'

      assert_equal 'myamazonaccesskeyid', app.secrets.aws_access_key_id
      assert_equal 'myamazonsecretaccesskey', app.secrets.aws_secret_access_key
    end

    test "shared secrets saved in config/secrets.yml are loaded in app secrets" do
      app_file 'config/secrets.yml', <<-YAML
        shared:
          api_key: 3b7cd727
      YAML

      app 'development'

      assert_equal '3b7cd727', app.secrets.api_key
    end

    test "shared secrets will yield to environment specific secrets" do
      app_file 'config/secrets.yml', <<-YAML
        shared:
          api_key: 3b7cd727

        development:
          api_key: abc12345
      YAML

      app 'development'

      assert_equal 'abc12345', app.secrets.api_key
    end

    test "blank config/secrets.yml does not crash the loading process" do
      app_file 'config/secrets.yml', <<-YAML
      YAML

      app 'development'

      assert_nil app.secrets.not_defined
    end

    test "config.secret_key_base over-writes a blank secrets.secret_key_base" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_key_base = "iaminallyoursecretkeybase"
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
      YAML

      app 'development'

      assert_equal "iaminallyoursecretkeybase", app.secrets.secret_key_base
    end

    test "uses ActiveSupport::LegacyKeyGenerator as app.key_generator when secrets.secret_key_base is blank" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = "b3c631c314c0bbca50c1b2843150fe33"
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
      YAML

      app 'development'

      assert_equal 'b3c631c314c0bbca50c1b2843150fe33', app.config.secret_token
      assert_equal nil, app.secrets.secret_key_base
      assert_equal app.key_generator.class, ActiveSupport::LegacyKeyGenerator
    end

    test "uses ActiveSupport::LegacyKeyGenerator with config.secret_token as app.key_generator when secrets.secret_key_base is blank" do
      app_file 'config/initializers/secret_token.rb', <<-RUBY
        Rails.application.config.secret_token = ""
      RUBY
      app_file 'config/secrets.yml', <<-YAML
        development:
          secret_key_base:
      YAML

      app 'development'

      assert_equal '', app.config.secret_token
      assert_equal nil, app.secrets.secret_key_base
      assert_raise ArgumentError, /\AA secret is required/ do
        app.key_generator
      end
    end

    test "protect from forgery is the default in a new app" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          render inline: "<%= csrf_meta_tags %>"
        end
      end

      get "/"
      assert last_response.body =~ /csrf\-param/
    end

    test "default form builder specified as a string" do
      app_file 'config/initializers/form_builder.rb', <<-RUBY
      class CustomFormBuilder < ActionView::Helpers::FormBuilder
        def text_field(attribute, *args)
          label(attribute) + super(attribute, *args)
        end
      end
      Rails.configuration.action_view.default_form_builder = "CustomFormBuilder"
      RUBY

      app_file 'app/models/post.rb', <<-RUBY
      class Post
        include ActiveModel::Model
        attr_accessor :name
      end
      RUBY


      app_file 'app/controllers/posts_controller.rb', <<-RUBY
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

      app 'development'

      get "/posts"
      assert_match(/label/, last_response.body)
    end

    test "default method for update can be changed" do
      app_file 'app/models/post.rb', <<-RUBY
      class Post
        include ActiveModel::Model
        def to_key; [1]; end
        def persisted?; true; end
      end
      RUBY

      token = "cf50faa3fe97702ca1ae"

      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ApplicationController
        def show
          render inline: "<%= begin; form_for(Post.new) {}; rescue => e; e.to_s; end %>"
        end

        def update
          render text: "update"
        end

        private

        def form_authenticity_token(*args); token; end # stub the authenticity token
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app 'development'

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
        application.config.action_controller.request_forgery_protection_token = '_xsrf_token_here'
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

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor], ::Mail.class_variable_get(:@@delivery_interceptors)
    end

    test "registers multiple interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.interceptors = [MyMailInterceptor, "MyOtherMailInterceptor"]
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor, ::MyOtherMailInterceptor], ::Mail.class_variable_get(:@@delivery_interceptors)
    end

    test "registers preview interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.preview_interceptors = MyPreviewMailInterceptor
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [ActionMailer::InlinePreviewInterceptor, ::MyPreviewMailInterceptor], ActionMailer::Base.preview_interceptors
    end

    test "registers multiple preview interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.preview_interceptors = [MyPreviewMailInterceptor, "MyOtherPreviewMailInterceptor"]
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [ActionMailer::InlinePreviewInterceptor, MyPreviewMailInterceptor, MyOtherPreviewMailInterceptor], ActionMailer::Base.preview_interceptors
    end

    test "default preview interceptor can be removed" do
      app_file 'config/initializers/preview_interceptors.rb', <<-RUBY
        ActionMailer::Base.preview_interceptors.delete(ActionMailer::InlinePreviewInterceptor)
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [], ActionMailer::Base.preview_interceptors
    end

    test "registers observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = MyMailObserver
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailObserver], ::Mail.class_variable_get(:@@delivery_notification_observers)
    end

    test "registers multiple observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = [MyMailObserver, "MyOtherMailObserver"]
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal [::MyMailObserver, ::MyOtherMailObserver], ::Mail.class_variable_get(:@@delivery_notification_observers)
    end

    test "allows setting the queue name for the ActionMailer::DeliveryJob" do
      add_to_config <<-RUBY
        config.action_mailer.deliver_later_queue_name = 'test_default'
      RUBY

      app 'development'

      require "mail"
      _ = ActionMailer::Base

      assert_equal 'test_default', ActionMailer::Base.class_variable_get(:@@deliver_later_queue_name)
    end

    test "valid timezone is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.time_zone = "Wellington"
      RUBY

      app 'development'

      assert_equal "Wellington", Rails.application.config.time_zone
    end

    test "raises when an invalid timezone is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.time_zone = "That big hill over yonder hill"
      RUBY

      assert_raise(ArgumentError) do
        app 'development'
      end
    end

    test "valid beginning of week is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.beginning_of_week = :wednesday
      RUBY

      app 'development'

      assert_equal :wednesday, Rails.application.config.beginning_of_week
    end

    test "raises when an invalid beginning of week is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.beginning_of_week = :invalid
      RUBY

      assert_raise(ArgumentError) do
        app 'development'
      end
    end

    test "config.action_view.cache_template_loading with cache_classes default" do
      add_to_config "config.cache_classes = true"

      app 'development'
      require 'action_view/base'

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading without cache_classes default" do
      add_to_config "config.cache_classes = false"

      app 'development'
      require 'action_view/base'

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = false" do
      add_to_config <<-RUBY
        config.cache_classes = true
        config.action_view.cache_template_loading = false
      RUBY

      app 'development'
      require 'action_view/base'

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = true" do
      add_to_config <<-RUBY
        config.cache_classes = false
        config.action_view.cache_template_loading = true
      RUBY

      app 'development'
      require 'action_view/base'

      assert_equal true, ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading with cache_classes in an environment" do
      build_app(initializers: true)
      add_to_env_config "development", "config.cache_classes = false"

      # These requires are to emulate an engine loading Action View before the application
      require 'action_view'
      require 'action_view/railtie'
      require 'action_view/base'

      app 'development'

      assert_equal false, ActionView::Resolver.caching?
    end

    test "config.action_dispatch.show_exceptions is sent in env" do
      make_basic_app do |application|
        application.config.action_dispatch.show_exceptions = true
      end

      class ::OmgController < ActionController::Base
        def index
          render text: env["action_dispatch.show_exceptions"]
        end
      end

      get "/"
      assert_equal 'true', last_response.body
    end

    test "config.action_controller.wrap_parameters is set in ActionController::Base" do
      app_file 'config/initializers/wrap_parameters.rb', <<-RUBY
        ActionController::Base.wrap_parameters format: [:json]
      RUBY

      app_file 'app/models/post.rb', <<-RUBY
      class Post
        def self.attribute_names
          %w(title)
        end
      end
      RUBY

      app_file 'app/controllers/application_controller.rb', <<-RUBY
      class ApplicationController < ActionController::Base
        protect_from_forgery with: :reset_session # as we are testing API here
      end
      RUBY

      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ApplicationController
        def create
          render text: params[:post].inspect
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      app 'development'

      post "/posts.json", '{ "title": "foo", "name": "bar" }', "CONTENT_TYPE" => "application/json"
      assert_equal '<ActionController::Parameters {"title"=>"foo"} permitted: false>', last_response.body
    end

    test "config.action_controller.permit_all_parameters = true" do
      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ActionController::Base
        def create
          render text: params[:post].permitted? ? "permitted" : "forbidden"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.permit_all_parameters = true
      RUBY

      app 'development'

      post "/posts", {post: {"title" =>"zomg"}}
      assert_equal 'permitted', last_response.body
    end

    test "config.action_controller.action_on_unpermitted_parameters = :raise" do
      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ActionController::Base
        def create
          render text: params.require(:post).permit(:name)
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
        config.action_controller.action_on_unpermitted_parameters = :raise
      RUBY

      app 'development'

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters

      post "/posts", {post: {"title" =>"zomg"}}
      assert_match "We're sorry, but something went wrong", last_response.body
    end

    test "config.action_controller.always_permitted_parameters are: controller, action by default" do
      app 'development'
      assert_equal %w(controller action), ActionController::Parameters.always_permitted_parameters
    end

    test "config.action_controller.always_permitted_parameters = ['controller', 'action', 'format']" do
      add_to_config <<-RUBY
        config.action_controller.always_permitted_parameters = %w( controller action format )
      RUBY

      app 'development'

      assert_equal %w( controller action format ), ActionController::Parameters.always_permitted_parameters
    end

    test "config.action_controller.always_permitted_parameters = ['controller','action','format'] does not raise exception" do
      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ActionController::Base
        def create
          render text: params.permit(post: [:title])
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

      app 'development'

      assert_equal :raise, ActionController::Parameters.action_on_unpermitted_parameters

      post "/posts", {post: {"title" =>"zomg"}, format: "json"}
      assert_equal 200, last_response.status
    end

    test "config.action_controller.action_on_unpermitted_parameters is :log by default on development" do
      app 'development'

      assert_equal :log, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_controller.action_on_unpermitted_parameters is :log by default on test" do
      app 'test'

      assert_equal :log, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_controller.action_on_unpermitted_parameters is false by default on production" do
      app 'production'

      assert_equal false, ActionController::Parameters.action_on_unpermitted_parameters
    end

    test "config.action_dispatch.ignore_accept_header" do
      make_basic_app do |application|
        application.config.action_dispatch.ignore_accept_header = true
      end

      class ::OmgController < ActionController::Base
        def index
          respond_to do |format|
            format.html { render text: "HTML" }
            format.xml { render text: "XML" }
          end
        end
      end

      get "/", {}, "HTTP_ACCEPT" => "application/xml"
      assert_equal 'HTML', last_response.body

      get "/", { format: :xml }, "HTTP_ACCEPT" => "application/xml"
      assert_equal 'XML', last_response.body
    end

    test "Rails.application#env_config exists and include some existing parameters" do
      make_basic_app

      assert_respond_to app, :env_config
      assert_equal      app.env_config['action_dispatch.parameter_filter'],  app.config.filter_parameters
      assert_equal      app.env_config['action_dispatch.show_exceptions'],   app.config.action_dispatch.show_exceptions
      assert_equal      app.env_config['action_dispatch.logger'],            Rails.logger
      assert_equal      app.env_config['action_dispatch.backtrace_cleaner'], Rails.backtrace_cleaner
      assert_equal      app.env_config['action_dispatch.key_generator'],     Rails.application.key_generator
    end

    test "config.colorize_logging default is true" do
      make_basic_app
      assert app.config.colorize_logging
    end

    test "config.session_store with :active_record_store with activerecord-session_store gem" do
      begin
        make_basic_app do |application|
          ActionDispatch::Session::ActiveRecordStore = Class.new(ActionDispatch::Session::CookieStore)
          application.config.session_store :active_record_store
        end
      ensure
        ActionDispatch::Session.send :remove_const, :ActiveRecordStore
      end
    end

    test "config.session_store with :active_record_store without activerecord-session_store gem" do
      assert_raise RuntimeError, /activerecord-session_store/ do
        make_basic_app do |application|
          application.config.session_store :active_record_store
        end
      end
    end

    test "default session store initializer does not overwrite the user defined session store even if it is disabled" do
      make_basic_app do |application|
        application.config.session_store :disabled
      end

      assert_equal nil, app.config.session_store
    end

    test "default session store initializer sets session store to cookie store" do
      session_options = { key: "_myapp_session", cookie_only: true }
      make_basic_app

      assert_equal ActionDispatch::Session::CookieStore, app.config.session_store
      assert_equal session_options, app.config.session_options
    end

    test "config.log_level with custom logger" do
      make_basic_app do |application|
        application.config.logger = Logger.new(STDOUT)
        application.config.log_level = :info
      end
      assert_equal Logger::INFO, Rails.logger.level
    end

    test "respond_to? accepts include_private" do
      make_basic_app

      assert_not Rails.configuration.respond_to?(:method_missing)
      assert Rails.configuration.respond_to?(:method_missing, true)
    end

    test "config.active_record.dump_schema_after_migration is false on production" do
      build_app

      app 'production'

      assert_not ActiveRecord::Base.dump_schema_after_migration
    end

    test "config.active_record.dump_schema_after_migration is true by default on development" do
      app 'development'

      assert ActiveRecord::Base.dump_schema_after_migration
    end

    test "config.annotations wrapping SourceAnnotationExtractor::Annotation class" do
      make_basic_app do |application|
        application.config.annotations.register_extensions("coffee") do |tag|
          /#\s*(#{tag}):?\s*(.*)$/
        end
      end

      assert_not_nil SourceAnnotationExtractor::Annotation.extensions[/\.(coffee)$/]
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

      app 'development'
      assert_not Rails.configuration.ran_block

      require 'rake'
      require 'rake/testtask'
      require 'rdoc/task'

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

      app 'development'
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

      app 'development'
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

      app 'development'
      assert_not Rails.configuration.ran_block

      Rails.application.load_runner
      assert Rails.configuration.ran_block
    end

    test "loading the first existing database configuration available" do
      app_file 'config/environments/development.rb', <<-RUBY

      Rails.application.configure do
        config.paths.add 'config/database', with: 'config/nonexistent.yml'
        config.paths['config/database'] << 'config/database.yml'
        end
      RUBY

      app 'development'

      assert_kind_of Hash, Rails.application.config.database_configuration
    end

    test 'raises with proper error message if no database configuration found' do
      FileUtils.rm("#{app_path}/config/database.yml")
      app 'development'
      err = assert_raises RuntimeError do
        Rails.application.config.database_configuration
      end
      assert_match 'config/database', err.message
    end

    test 'config.action_mailer.show_previews defaults to true in development' do
      app 'development'

      assert Rails.application.config.action_mailer.show_previews
    end

    test 'config.action_mailer.show_previews defaults to false in production' do
      app 'production'

      assert_equal false, Rails.application.config.action_mailer.show_previews
    end

    test 'config.action_mailer.show_previews can be set in the configuration file' do
      add_to_config <<-RUBY
        config.action_mailer.show_previews = true
      RUBY

      app 'production'

      assert_equal true, Rails.application.config.action_mailer.show_previews
    end

    test "config_for loads custom configuration from yaml files" do
      app_file 'config/custom.yml', <<-RUBY
      development:
        key: 'custom key'
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      app 'development'

      assert_equal 'custom key', Rails.application.config.my_custom_config['key']
    end

    test "config_for uses the Pathname object if it is provided" do
      app_file 'config/custom.yml', <<-RUBY
      development:
        key: 'custom key'
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for(Pathname.new(Rails.root.join("config/custom.yml")))
      RUBY

      app 'development'

      assert_equal 'custom key', Rails.application.config.my_custom_config['key']
    end

    test "config_for raises an exception if the file does not exist" do
      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      exception = assert_raises(RuntimeError) do
        app 'development'
      end

      assert_equal "Could not load configuration. No such file - #{app_path}/config/custom.yml", exception.message
    end

    test "config_for without the environment configured returns an empty hash" do
      app_file 'config/custom.yml', <<-RUBY
      test:
        key: 'custom key'
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      app 'development'

      assert_equal({}, Rails.application.config.my_custom_config)
    end

    test "config_for with empty file returns an empty hash" do
      app_file 'config/custom.yml', <<-RUBY
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      app 'development'

      assert_equal({}, Rails.application.config.my_custom_config)
    end

    test "config_for containing ERB tags should evaluate" do
      app_file 'config/custom.yml', <<-RUBY
      development:
        key: <%= 'custom key' %>
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      app 'development'

      assert_equal 'custom key', Rails.application.config.my_custom_config['key']
    end

    test "config_for with syntax error show a more descriptive exception" do
      app_file 'config/custom.yml', <<-RUBY
      development:
        key: foo:
      RUBY

      add_to_config <<-RUBY
        config.my_custom_config = config_for('custom')
      RUBY

      exception = assert_raises(RuntimeError) do
        app 'development'
      end

      assert_match 'YAML syntax error occurred while parsing', exception.message
    end

    test "config_for allows overriding the environment" do
      app_file 'config/custom.yml', <<-RUBY
        test:
          key: 'walrus'
        production:
            key: 'unicorn'
      RUBY

      add_to_config <<-RUBY
          config.my_custom_config = config_for('custom', env: 'production')
      RUBY
      require "#{app_path}/config/environment"

      assert_equal 'unicorn', Rails.application.config.my_custom_config['key']
    end

    test "api_only is false by default" do
      app 'development'
      refute Rails.application.config.api_only
    end

    test "api_only generator config is set when api_only is set" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY
      app 'development'

      Rails.application.load_generators
      assert Rails.configuration.api_only
    end

    test "debug_exception_response_format is :api by default if api_only is enabled" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY
      app 'development'

      assert_equal :api, Rails.configuration.debug_exception_response_format
    end

    test "debug_exception_response_format can be overridden" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY

      app_file 'config/environments/development.rb', <<-RUBY
      Rails.application.configure do
        config.debug_exception_response_format = :default
      end
      RUBY

      app 'development'

      assert_equal :default, Rails.configuration.debug_exception_response_format
    end
  end
end
