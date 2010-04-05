require "isolation/abstract_unit"

module ApplicationTests
  class ConfigurationTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

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
      FileUtils.rm_rf(new_app) if File.directory?(new_app)
    end

    test "Rails::Application.instance is nil until app is initialized" do
      require 'rails'
      assert_nil Rails::Application.instance
      require "#{app_path}/config/environment"
      assert_equal AppTemplate::Application.instance, Rails::Application.instance
    end

    test "Rails::Application responds to all instance methods" do
      require "#{app_path}/config/environment"
      assert_respond_to Rails::Application, :routes_reloader
      assert_equal Rails::Application.routes_reloader, Rails.application.routes_reloader
      assert_equal Rails::Application.routes_reloader, AppTemplate::Application.routes_reloader
    end

    test "Rails::Application responds to paths" do
      require "#{app_path}/config/environment"
      assert_respond_to AppTemplate::Application, :paths
      assert_equal AppTemplate::Application.paths.app.views.to_a, ["#{app_path}/app/views"]
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

    test "marking the application as threadsafe sets the correct config variables" do
      add_to_config <<-RUBY
        config.threadsafe!
      RUBY

      require "#{app_path}/config/application"
      assert AppTemplate::Application.config.allow_concurrency
    end

    test "the application can be marked as threadsafe when there are no frameworks" do
      FileUtils.rm_rf("#{app_path}/config/environments")
      add_to_config <<-RUBY
        config.threadsafe!
      RUBY

      use_frameworks []

      assert_nothing_raised do
        require "#{app_path}/config/application"
      end
    end

    test "Frameworks are not preloaded by default" do
      require "#{app_path}/config/environment"

      assert ActionController.autoload?(:RecordIdentifier)
    end

    test "frameworks are preloaded with config.preload_frameworks is set" do
      add_to_config <<-RUBY
        config.preload_frameworks = true
      RUBY

      require "#{app_path}/config/environment"

      assert !ActionController.autoload?(:RecordIdentifier)
    end

    test "runtime error is raised if config.frameworks= is used" do
      add_to_config "config.frameworks = []"

      assert_raises RuntimeError do
        require "#{app_path}/config/environment"
      end
    end

    test "runtime error is raised if config.frameworks is used" do
      add_to_config "config.frameworks -= []"

      assert_raises RuntimeError do
        require "#{app_path}/config/environment"
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

    test "config.to_prepare is forwarded to ActionDispatch" do
      $prepared = false

      add_to_config <<-RUBY
        config.to_prepare do
          $prepared = true
        end
      RUBY

      assert !$prepared

      require "#{app_path}/config/environment"
      require 'rack/test'
      extend Rack::Test::Methods

      get "/"
      assert $prepared
    end

    def make_basic_app
      require "rails"
      require "action_controller/railtie"

      app = Class.new(Rails::Application)

      yield app if block_given?

      app.config.session_store :disabled
      app.initialize!

      app.routes.draw do
        match "/" => "omg#index"
      end

      require 'rack/test'
      extend Rack::Test::Methods
    end

    test "config.action_dispatch.x_sendfile_header defaults to ''" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.read(__FILE__), last_response.body
    end

    test "config.action_dispatch.x_sendfile_header can be set" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = "X-Sendfile"
      end

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Sendfile"]
    end

    test "config.action_dispatch.x_sendfile_header is sent to Rack::Sendfile" do
      make_basic_app do |app|
        app.config.action_dispatch.x_sendfile_header = 'X-Lighttpd-Send-File'
      end

      class ::OmgController < ActionController::Base
        def index
          send_file __FILE__
        end
      end

      get "/"
      assert_equal File.expand_path(__FILE__), last_response.headers["X-Lighttpd-Send-File"]
    end

    test "config.secret_token is sent in env" do
      make_basic_app do |app|
        app.config.secret_token = 'ThisIsASECRET123'
      end

      class ::OmgController < ActionController::Base
        def index
          cookies.signed[:some_key] = "some_value"
          render :text => env["action_dispatch.secret_token"]
        end
      end

      get "/"
      assert_equal 'ThisIsASECRET123', last_response.body
    end

    test "protect from forgery is the default in a new app" do
      make_basic_app

      class ::OmgController < ActionController::Base
        protect_from_forgery

        def index
          render :inline => "<%= csrf_meta_tag %>"
        end
      end

      get "/"
      assert last_response.body =~ /csrf\-param/
    end
  end
end
