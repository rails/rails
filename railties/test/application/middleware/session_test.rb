# encoding: utf-8
require 'isolation/abstract_unit'
require 'rack/test'

module ApplicationTests
  class MiddlewareSessionTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app
      boot_rails
      FileUtils.rm_rf "#{app_path}/config/environments"
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "config.force_ssl sets cookie to secure only" do
      add_to_config "config.force_ssl = true"
      require "#{app_path}/config/environment"
      assert app.config.session_options[:secure], "Expected session to be marked as secure"
    end

    test "session is not loaded if it's not used" do
      make_basic_app

      class ::OmgController < ActionController::Base
        def index
          if params[:flash]
            flash[:notice] = "notice"
          end

          render nothing: true
        end
      end

      get "/?flash=true"
      get "/"

      assert last_request.env["HTTP_COOKIE"]
      assert !last_response.headers["Set-Cookie"]
    end

    test "session is empty and isn't saved on unverified request when using :null_session protect method" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get  ':controller(/:action)'
          post ':controller(/:action)'
        end
      RUBY

      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          protect_from_forgery with: :null_session

          def write_session
            session[:foo] = 1
            render nothing: true
          end

          def read_session
            render text: session[:foo].inspect
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.action_controller.allow_forgery_protection = true
      RUBY

      require "#{app_path}/config/environment"

      get '/foo/write_session'
      get '/foo/read_session'
      assert_equal '1', last_response.body

      post '/foo/read_session'               # Read session using POST request without CSRF token
      assert_equal 'nil', last_response.body # Stored value shouldn't be accessible

      post '/foo/write_session' # Write session using POST request without CSRF token
      get '/foo/read_session'   # Session shouldn't be changed
      assert_equal '1', last_response.body
    end

    test "cookie jar is empty and isn't saved on unverified request when using :null_session protect method" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get  ':controller(/:action)'
          post ':controller(/:action)'
        end
      RUBY

      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          protect_from_forgery with: :null_session

          def write_cookie
            cookies[:foo] = '1'
            render nothing: true
          end

          def read_cookie
            render text: cookies[:foo].inspect
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.action_controller.allow_forgery_protection = true
      RUBY

      require "#{app_path}/config/environment"

      get '/foo/write_cookie'
      get '/foo/read_cookie'
      assert_equal '"1"', last_response.body

      post '/foo/read_cookie'                # Read cookie using POST request without CSRF token
      assert_equal 'nil', last_response.body # Stored value shouldn't be accessible

      post '/foo/write_cookie' # Write cookie using POST request without CSRF token
      get '/foo/read_cookie'   # Cookie shouldn't be changed
      assert_equal '"1"', last_response.body
    end

    test "session using encrypted cookie store" do
      app_file 'config/routes.rb', <<-RUBY
        AppTemplate::Application.routes.draw do
          get ':controller(/:action)'
        end
      RUBY

      controller :foo, <<-RUBY
        class FooController < ActionController::Base
          def write_session
            session[:foo] = 1
            render nothing: true
          end

          def read_session
            render text: session[:foo]
          end

          def read_encrypted_cookie
            render text: cookies.encrypted[:_myapp_session]['foo']
          end

          def read_raw_cookie
            render text: cookies[:_myapp_session]
          end
        end
      RUBY

      add_to_config <<-RUBY
        config.session_store :encrypted_cookie_store, key: '_myapp_session'
        config.action_dispatch.derive_signed_cookie_key = true
      RUBY

      require "#{app_path}/config/environment"

      get '/foo/write_session'
      get '/foo/write_session'
      get '/foo/read_session'
      assert_equal '1', last_response.body

      get '/foo/read_encrypted_cookie'
      assert_equal '1', last_response.body

      secret = app.key_generator.generate_key('encrypted cookie')
      sign_secret = app.key_generator.generate_key('signed encrypted cookie')
      encryptor = ActiveSupport::MessageEncryptor.new(secret, sign_secret)

      get '/foo/read_raw_cookie'
      assert_equal 1, encryptor.decrypt_and_verify(last_response.body)['foo']
    end
  end
end
