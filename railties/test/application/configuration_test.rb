require "isolation/abstract_unit"
require 'rack/test'
require 'env_helpers'

class ::MyMailInterceptor
  def self.delivering_email(email); email; end
end

class ::MyOtherMailInterceptor < ::MyMailInterceptor; end

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

    def app
      @app ||= Rails.application
    end

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf("#{app_path}/config/environments")
    end

    def teardown
      teardown_app
      FileUtils.rm_rf(new_app) if File.directory?(new_app)
    end

    test "Rails.env does not set the RAILS_ENV environment variable which would leak out into rake tasks" do
      require "rails"

      switch_env "RAILS_ENV", nil do
        Rails.env = "development"
        assert_equal "development", Rails.env
        assert_nil ENV['RAILS_ENV']
      end
    end

    test "a renders exception on pending migration" do
      add_to_config <<-RUBY
        config.active_record.migration_error    = :page_load
        config.consider_all_requests_local      = true
        config.action_dispatch.show_exceptions  = true
      RUBY

      require "#{app_path}/config/environment"
      ActiveRecord::Migrator.stubs(:needs_migration?).returns(true)

      get "/foo"
      assert_equal 500, last_response.status
      assert_match "ActiveRecord::PendingMigrationError", last_response.body
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
      require "#{app_path}/config/environment"
      assert_equal AppTemplate::Application.instance, Rails.application
    end

    test "Rails.application responds to all instance methods" do
      require "#{app_path}/config/environment"
      assert_respond_to Rails.application, :routes_reloader
      assert_equal Rails.application.routes_reloader, AppTemplate::Application.routes_reloader
    end

    test "Rails::Application responds to paths" do
      require "#{app_path}/config/environment"
      assert_respond_to AppTemplate::Application, :paths
      assert_equal AppTemplate::Application.paths["app/views"].expanded, ["#{app_path}/app/views"]
    end

    test "the application root is set correctly" do
      require "#{app_path}/config/environment"
      assert_equal Pathname.new(app_path), Rails.application.root
    end

    test "the application root can be seen from the application singleton" do
      require "#{app_path}/config/environment"
      assert_equal Pathname.new(app_path), AppTemplate::Application.root
    end

    test "the application root can be set" do
      copy_app
      add_to_config <<-RUBY
        config.root = '#{new_app}'
      RUBY

      use_frameworks []

      require "#{app_path}/config/environment"
      assert_equal Pathname.new(new_app), Rails.application.root
    end

    test "the application root is Dir.pwd if there is no config.ru" do
      File.delete("#{app_path}/config.ru")

      use_frameworks []

      Dir.chdir("#{app_path}") do
        require "#{app_path}/config/environment"
        assert_equal Pathname.new("#{app_path}"), Rails.application.root
      end
    end

    test "Rails.root should be a Pathname" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY
      require "#{app_path}/config/environment"
      assert_instance_of Pathname, Rails.root
    end

    test "Rails.public_path should be a Pathname" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY
      require "#{app_path}/config/environment"
      assert_instance_of Pathname, Rails.public_path
    end

    test "initialize an eager loaded, cache classes app" do
      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      require "#{app_path}/config/application"
      assert AppTemplate::Application.initialize!
    end

    test "application is always added to eager_load namespaces" do
      require "#{app_path}/config/application"
      assert AppTemplate::Application, AppTemplate::Application.config.eager_load_namespaces
    end

    test "the application can be eager loaded even when there are no frameworks" do
      FileUtils.rm_rf("#{app_path}/config/environments")
      add_to_config <<-RUBY
        config.eager_load = true
        config.cache_classes = true
      RUBY

      use_frameworks []

      assert_nothing_raised do
        require "#{app_path}/config/application"
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters" do
      add_to_config <<-RUBY
        config.filter_parameters += [ :foo, 'bar', lambda { |key, value|
          value = value.reverse if key =~ /baz/
        }]
      RUBY

      assert_nothing_raised do
        require "#{app_path}/config/application"
      end
    end

    test "filter_parameters should be able to set via config.filter_parameters in an initializer" do
      app_file 'config/initializers/filter_parameters_logging.rb', <<-RUBY
        Rails.application.config.filter_parameters += [ :password, :foo, 'bar' ]
      RUBY

      require "#{app_path}/config/environment"

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

      require "#{app_path}/config/environment"

      get "/"
      assert $prepared
    end

    def assert_utf8
      assert_equal Encoding::UTF_8, Encoding.default_external
      assert_equal Encoding::UTF_8, Encoding.default_internal
    end

    test "skipping config.encoding still results in 'utf-8' as the default" do
      require "#{app_path}/config/application"
      assert_utf8
    end

    test "config.encoding sets the default encoding" do
      add_to_config <<-RUBY
        config.encoding = "utf-8"
      RUBY

      require "#{app_path}/config/application"
      assert_utf8
    end

    test "config.paths.public sets Rails.public_path" do
      add_to_config <<-RUBY
        config.paths["public"] = "somewhere"
      RUBY

      require "#{app_path}/config/application"
      assert_equal Pathname.new(app_path).join("somewhere"), Rails.public_path
    end

    test "Use key_generator when secret_key_base is set" do
      make_basic_app do |app|
        app.config.secret_key_base = 'b3c631c314c0bbca50c1b2843150fe33'
        app.config.session_store :disabled
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

    test "default method for update can be changed" do
      app_file 'app/models/post.rb', <<-RUBY
      class Post
        extend ActiveModel::Naming
        def to_key; [1]; end
        def persisted?; true; end
      end
      RUBY

      app_file 'app/controllers/posts_controller.rb', <<-RUBY
      class PostsController < ApplicationController
        def show
          render inline: "<%= begin; form_for(Post.new) {}; rescue => e; e.to_s; end %>"
        end

        def update
          render text: "update"
        end
      end
      RUBY

      add_to_config <<-RUBY
        routes.prepend do
          resources :posts
        end
      RUBY

      require "#{app_path}/config/environment"

      token = "cf50faa3fe97702ca1ae"
      PostsController.any_instance.stubs(:form_authenticity_token).returns(token)
      params = {authenticity_token: token}

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
      make_basic_app do
        app.config.action_controller.request_forgery_protection_token = '_xsrf_token_here'
      end

      class ::OmgController < ActionController::Base
        def index
          render inline: "<%= csrf_meta_tags %>"
        end
      end

      get "/"
      assert last_response.body =~ /_xsrf_token_here/
    end

    test "sets ActionDispatch.test_app" do
      make_basic_app
      assert_equal Rails.application, ActionDispatch.test_app
    end

    test "sets ActionDispatch::Response.default_charset" do
      make_basic_app do |app|
        app.config.action_dispatch.default_charset = "utf-16"
      end

      assert_equal "utf-16", ActionDispatch::Response.default_charset
    end

    test "registers interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.interceptors = MyMailInterceptor
      RUBY

      require "#{app_path}/config/environment"
      require "mail"

      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor], ::Mail.send(:class_variable_get, "@@delivery_interceptors")
    end

    test "registers multiple interceptors with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.interceptors = [MyMailInterceptor, "MyOtherMailInterceptor"]
      RUBY

      require "#{app_path}/config/environment"
      require "mail"

      _ = ActionMailer::Base

      assert_equal [::MyMailInterceptor, ::MyOtherMailInterceptor], ::Mail.send(:class_variable_get, "@@delivery_interceptors")
    end

    test "registers observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = MyMailObserver
      RUBY

      require "#{app_path}/config/environment"
      require "mail"

      _ = ActionMailer::Base

      assert_equal [::MyMailObserver], ::Mail.send(:class_variable_get, "@@delivery_notification_observers")
    end

    test "registers multiple observers with ActionMailer" do
      add_to_config <<-RUBY
        config.action_mailer.observers = [MyMailObserver, "MyOtherMailObserver"]
      RUBY

      require "#{app_path}/config/environment"
      require "mail"

      _ = ActionMailer::Base

      assert_equal [::MyMailObserver, ::MyOtherMailObserver], ::Mail.send(:class_variable_get, "@@delivery_notification_observers")
    end

    test "valid timezone is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
          config.time_zone = "Wellington"
      RUBY

      require "#{app_path}/config/environment"

      assert_equal Time.find_zone!("Wellington"), Time.zone_default
    end

    test "timezone can be set on initializers" do
      app_file "config/initializers/locale.rb", <<-RUBY
        Rails.application.config.time_zone = "Central Time (US & Canada)"
      RUBY

      require "#{app_path}/config/environment"

      assert_equal Time.find_zone!("Central Time (US & Canada)"), Time.zone_default
    end

    test "raises when an invalid timezone is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
          config.time_zone = "That big hill over yonder hill"
      RUBY

      assert_raise(ArgumentError) do
        require "#{app_path}/config/environment"
      end
    end

    test "valid beginning of week is setup correctly" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
          config.beginning_of_week = :wednesday
      RUBY

      require "#{app_path}/config/environment"

      assert_equal :wednesday, Rails.application.config.beginning_of_week
    end

    test "raises when an invalid beginning of week is defined in the config" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
          config.beginning_of_week = :invalid
      RUBY

      assert_raise(ArgumentError) do
        require "#{app_path}/config/environment"
      end
    end

    test "config.action_view.cache_template_loading with cache_classes default" do
      add_to_config "config.cache_classes = true"
      require "#{app_path}/config/environment"
      require 'action_view/base'

      assert ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading without cache_classes default" do
      add_to_config "config.cache_classes = false"
      require "#{app_path}/config/environment"
      require 'action_view/base'

      assert !ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = false" do
      add_to_config <<-RUBY
        config.cache_classes = true
        config.action_view.cache_template_loading = false
      RUBY
      require "#{app_path}/config/environment"
      require 'action_view/base'

      assert !ActionView::Resolver.caching?
    end

    test "config.action_view.cache_template_loading = true" do
      add_to_config <<-RUBY
        config.cache_classes = false
        config.action_view.cache_template_loading = true
      RUBY
      require "#{app_path}/config/environment"
      require 'action_view/base'

      assert ActionView::Resolver.caching?
    end

    test "config.action_dispatch.show_exceptions is sent in env" do
      make_basic_app do |app|
        app.config.action_dispatch.show_exceptions = true
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

      require "#{app_path}/config/environment"

      post "/posts.json", '{ "title": "foo", "name": "bar" }', "CONTENT_TYPE" => "application/json"
      assert_equal '{"title"=>"foo"}', last_response.body
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

      require "#{app_path}/config/environment"

      post "/posts", {post: {"title" =>"zomg"}}
      assert_equal 'permitted', last_response.body
    end

    test "config.action_dispatch.ignore_accept_header" do
      make_basic_app do |app|
        app.config.action_dispatch.ignore_accept_header = true
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
        make_basic_app do |app|
          ActionDispatch::Session::ActiveRecordStore = Class.new(ActionDispatch::Session::CookieStore)
          app.config.session_store :active_record_store
        end
      ensure
        ActionDispatch::Session.send :remove_const, :ActiveRecordStore
      end
    end

    test "config.session_store with :active_record_store without activerecord-session_store gem" do
      assert_raise RuntimeError, /activerecord-session_store/ do
        make_basic_app do |app|
          app.config.session_store :active_record_store
        end
      end
    end
  end
end
