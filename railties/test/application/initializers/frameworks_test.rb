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
        app("development")
      end
    end

    test "sets action_controller and action_mailer load paths" do
      add_to_config <<-RUBY
        config.root = "#{app_path}"
      RUBY

      app("development")

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

      app("development")
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

      app("development")
      assert Foo.new.respond_to?(:foo_url)
      assert Foo.new.respond_to?(:main_app)
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
            render inline: "<%= from_app_helper -%> <%= from_foo_helper %>"
          end

          def not_included_helper
            render inline: "<%= respond_to?(:from_bar_helper) -%>"
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
      app("development")
      assert_equal 2, ActionDispatch::Http::URL.tld_length
    end

    test "assignment config.encoding to default_charset" do
      charset = "Shift_JIS"
      add_to_config "config.encoding = '#{charset}'"
      app("development")
      assert_equal charset, ActionDispatch::Response.default_charset
    end

    test "URL builder is configured to use HTTPS when force_ssl is on" do
      app_file "config/environments/development.rb", <<-RUBY
        Rails.application.configure do
          config.force_ssl = true
        end
      RUBY

      app("development")
      assert_equal true, ActionDispatch::Http::URL.secure_protocol
    end

    # AS
    test "if there's no config.active_support.bare, all of ActiveSupport is required" do
      use_frameworks []
      app("development")
      assert_nothing_raised { [1, 2, 3].sample }
    end

    test "config.active_support.bare does not require all of ActiveSupport" do
      add_to_config "config.active_support.bare = true"

      use_frameworks []

      Dir.chdir("#{app_path}/app") do
        app("development")
        assert_raises(NoMethodError) { "hello".exclude? "lo" }
      end
    end

    # AR
    test "active_record extensions are applied to ActiveRecord" do
      add_to_config "config.active_record.table_name_prefix = 'tbl_'"
      app("development")
      assert_equal "tbl_", ActiveRecord::Base.table_name_prefix
    end

    test "database middleware doesn't initialize when activerecord is not in frameworks" do
      use_frameworks []
      app("development")
      assert !defined?(ActiveRecord::Base) || ActiveRecord.autoload?(:Base)
    end

    test "can boot with an unhealthy database" do
      rails %w(generate model post title:string)

      with_unhealthy_database do
        assert_nothing_raised do
          app("development")
        end
      end
    end

    test "use schema cache dump" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      Dir.chdir(app_path) do
        app("development")

        assert ActiveRecord::Base.schema_cache.data_sources("posts")
      end
    ensure
      ActiveRecord::Base.lease_connection.drop_table("posts", if_exists: true) # force drop posts table for test.
    end

    test "expire schema cache dump" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      Dir.chdir(app_path) do
        app("development")

        _, error = capture_io do
          assert_not ActiveRecord::Base.schema_cache.data_sources("posts")
        end

        assert_match(/Ignoring db\/schema_cache\.yml because it has expired/, error)
      end
    end

    test "expire schema cache dump if the version can't be checked because the database is unhealthy" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump)

      add_to_config <<-RUBY
        config.eager_load = true
      RUBY

      with_unhealthy_database do
        Dir.chdir(app_path) do
          app("development")

          assert_raises ActiveRecord::ConnectionNotEstablished do
            ActiveRecord::Base.lease_connection.execute("SELECT 1")
          end

          _, error = capture_io do
            assert_raises ActiveRecord::ConnectionNotEstablished do
              ActiveRecord::Base.schema_cache.columns("posts")
            end
          end

          assert_match(/Failed to validate the schema cache because of ActiveRecord::(ConnectionNotEstablished|DatabaseConnectionError)/, error)
        end
      end
    end

    test "does not expire schema cache dump if check_schema_cache_dump_version is false" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      Dir.chdir(app_path) do
        app("development")

        assert ActiveRecord::Base.connection_pool.schema_reflection.data_sources(:__unused__, "posts")
      end
    end

    test "does not expire schema cache dump if check_schema_cache_dump_version is false and the database unhealthy" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump db:rollback)

      add_to_config <<-RUBY
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      with_unhealthy_database do
        Dir.chdir(app_path) do
          app("development")

          assert ActiveRecord::Base.connection_pool.schema_reflection.data_sources(:__unused__, "posts")
          assert_raises ActiveRecord::ConnectionNotEstablished do
            ActiveRecord::Base.lease_connection.execute("SELECT 1")
          end
        end
      end
    end

    test "define attribute methods when schema cache is present and check_schema_cache_dump_version is false" do
      rails %w(generate model post title:string)
      rails %w(db:migrate db:schema:cache:dump)

      add_to_config <<-RUBY
        config.eager_load = true
        config.active_record.check_schema_cache_dump_version = false
      RUBY

      Dir.chdir(app_path) do
        app

        assert_predicate Post, :attribute_methods_generated?
      end
    end

    test "active record establish_connection uses Rails.env if DATABASE_URL is not set" do
      app("development")
      orig_database_url = ENV.delete("DATABASE_URL")
      orig_rails_env, Rails.env = Rails.env, "development"
      ActiveRecord::Base.establish_connection
      assert ActiveRecord::Base.lease_connection
      assert_match(/#{ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary").database}/, ActiveRecord::Base.connection_db_config.database)
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
      assert_match(/#{db_config.database}/, ActiveRecord::Base.connection_db_config.database)
    ensure
      ActiveRecord::Base.remove_connection
      ENV["DATABASE_URL"] = orig_database_url if orig_database_url
      Rails.env = orig_rails_env if orig_rails_env
    end

    test "active record establish_connection uses DATABASE_URL even if Rails.env is set" do
      app("development")
      orig_database_url = ENV.delete("DATABASE_URL")
      orig_rails_env, Rails.env = Rails.env, "development"
      database_url_db_name = "db/database_url_db.sqlite3"
      ENV["DATABASE_URL"] = "sqlite3:#{database_url_db_name}"
      ActiveRecord::Base.establish_connection
      assert ActiveRecord::Base.lease_connection
      assert_match(/#{database_url_db_name}/, ActiveRecord::Base.connection_db_config.database)
    ensure
      ActiveRecord::Base.remove_connection
      ENV["DATABASE_URL"] = orig_database_url if orig_database_url
      Rails.env = orig_rails_env if orig_rails_env
    end

    test "connections checked out during initialization are returned to the pool" do
      app_file "config/initializers/active_record.rb", <<-RUBY
        ActiveRecord::Base.lease_connection
      RUBY
      app("development")
      assert_not_predicate ActiveRecord::Base.connection_pool, :active_connection?
    end

    test "Current scopes in AR models are reset on reloading" do
      rails %w(generate model post)
      rails %w(db:migrate)

      app_file "app/models/a.rb", "A = 1"
      app_file "app/models/m.rb", "module M; end"
      app_file "app/models/post.rb", <<~RUBY
        class Post < ActiveRecord::Base
          def self.is_a?(_)
            false
          end

          def self.<(_)
            false
          end
        end
      RUBY

      app("development")

      assert A
      assert M
      Post.current_scope = Post
      assert_not_nil ActiveRecord::Scoping::ScopeRegistry.current_scope(Post) # precondition

      ActiveSupport::Dependencies.clear

      assert_nil ActiveRecord::Scoping::ScopeRegistry.current_scope(Post)
    end

    test "filters for Active Record encrypted attributes are added to config.filter_parameters only once" do
      rails %w(generate model post title:string)
      rails %w(db:migrate)

      app_file "app/models/post.rb", <<~RUBY
        class Post < ActiveRecord::Base
          encrypts :title
        end
      RUBY

      app("development")

      assert Post
      filter_parameters = Rails.application.config.filter_parameters.dup

      reload

      assert Post
      assert_equal filter_parameters, Rails.application.config.filter_parameters
    end

    test "ActiveRecord::MessagePack extensions are installed when using ActiveSupport::MessagePack::CacheSerializer" do
      rails %w(generate model post title:string)
      rails %w(db:migrate)

      add_to_config <<~RUBY
        config.cache_store = :file_store, #{app_path("tmp/cache").inspect}, { serializer: :message_pack }
      RUBY

      app("development")

      post = Post.create!(title: "Hello World")
      Rails.cache.write("hello", post)
      assert_equal post, Rails.cache.read("hello")
    end
  end
end
