# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"

module ApplicationTests
  class QueryLogsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods

    def setup
      build_app(multi_db: true)
      rails("generate", "scaffold", "Pet", "name:string", "--database=animals")
      app_file "app/models/user.rb", <<-RUBY
        class User < ActiveRecord::Base
        end
      RUBY

      app_file "app/controllers/users_controller.rb", <<-RUBY
        class UsersController < ApplicationController
          def index
            render inline: ActiveRecord::QueryLogs.call("", Pet.connection)
          end

          def dynamic_content
            Time.now.to_f.to_s
          end
        end
      RUBY

      app_file "app/controllers/name_spaced/users_controller.rb", <<-RUBY
        class NameSpaced::UsersController < ApplicationController
          def index
            render inline: ActiveRecord::QueryLogs.call("", ActiveRecord::Base.lease_connection)
          end
        end
      RUBY

      app_file "app/jobs/user_job.rb", <<-RUBY
        class UserJob < ActiveJob::Base
          def perform
            ActiveRecord::QueryLogs.call("", ActiveRecord::Base.lease_connection)
          end

          def dynamic_content
            Time.now.to_f.to_s
          end
        end
      RUBY

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get "/", to: "users#index"
          get "/namespaced/users", to: "name_spaced/users#index"
        end
      RUBY
    end

    def teardown
      teardown_app
    end

    def app
      @app ||= Rails.application
    end

    test "does not modify the query execution path by default" do
      boot_app

      assert_not_includes ActiveRecord.query_transformers, ActiveRecord::QueryLogs
    end

    test "prepends the query execution path when enabled" do
      add_to_config "config.active_record.query_log_tags_enabled = true"

      boot_app

      assert_includes ActiveRecord.query_transformers, ActiveRecord::QueryLogs
    end

    test "disables prepared statements when enabled" do
      add_to_config "config.active_record.query_log_tags_enabled = true"

      boot_app

      assert_predicate ActiveRecord, :disable_prepared_statements
    end

    test "controller and job tags are defined by default" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      app_file "config/initializers/active_record.rb", <<-RUBY
        raise "Expected prepared_statements to be enabled" unless ActiveRecord::Base.lease_connection.prepared_statements
        ActiveRecord::Base.lease_connection.execute("SELECT 1")
      RUBY

      boot_app

      assert_equal [ :application, :controller, :action, :job ], ActiveRecord::QueryLogs.tags
    end

    test "controller actions have tagging filters enabled by default" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags_format = :legacy"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_includes comment, "controller:users"
    end

    test "sqlcommenter formatting works when specified" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags_format = :sqlcommenter"

      add_to_config "config.active_record.query_log_tags = [ :pid ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_match(/pid='\d+'/, comment)
      assert_includes comment, "controller='users'"
    end

    test "controller actions tagging filters can be disabled" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.action_controller.log_query_tags_around_actions = false"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_not_includes comment, "controller:users"
    end

    test "database information works with multiple database applications" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :socket, :db_host, :database ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_equal("/*action='index',controller='users',database='storage%2Fproduction_animals.sqlite3'*/", comment)
    end

    test "source_location information is added if enabled" do
      add_to_config <<~RUBY
        config.active_record.query_log_tags_enabled = true
        config.active_record.query_log_tags = [ :source_location ]

        # Remove silencers, so we won't get all backtrace lines filtered.
        Rails.backtrace_cleaner.remove_silencers!
      RUBY

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_match(/source_location='.*\d+'/, comment)
    end

    test "controller tags are not doubled up if already configured" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :action, :job, :controller, :pid ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_match(/\/\*action='index',controller='users',pid='\d+'\*\//, comment)
    end

    test "namespace controller tags are not doubled up if already configured" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :action, :job, :namespaced_controller, :pid ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip

      assert_match(/\/\*action='index',namespaced_controller='users',pid='\d+'\*\//, comment)
    end

    test "job perform method has tagging filters enabled by default" do
      add_to_config "config.active_record.query_log_tags_enabled = true"

      boot_app

      comment = UserJob.new.perform_now

      assert_includes comment, "UserJob"
    end

    test "job perform method tagging filters can be disabled" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_job.log_query_tags_around_perform = false"

      boot_app

      comment = UserJob.new.perform_now

      assert_not_includes comment, "UserJob"
    end

    test "job tags are not doubled up if already configured" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :action, :job, :controller, :pid ]"

      boot_app

      comment = UserJob.new.perform_now

      assert_match(/\/\*job='UserJob',pid='\d+'\*\//, comment)
    end

    test "query cache is cleared between requests" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.cache_query_log_tags = true"
      add_to_config "config.active_record.query_log_tags = [ { dynamic: ->(context) { context[:controller]&.dynamic_content } } ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }

      first_tags = last_response.body

      get "/", {}, { "HTTPS" => "on" }

      second_tags = last_response.body

      assert_not_equal first_tags, second_tags
    end

    test "query cache is cleared between job executions" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.cache_query_log_tags = true"
      add_to_config "config.active_record.query_log_tags = [ { dynamic: ->(context) { context[:job]&.dynamic_content } } ]"

      boot_app

      first_tags = UserJob.new.perform_now
      second_tags = UserJob.new.perform_now

      assert_not_equal first_tags, second_tags
    end

    test "controller and namespaced_controller are named correctly" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :action, :namespaced_controller, :controller ]"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip
      assert_equal %(/*action='index',controller='users',namespaced_controller='users'*/), comment

      get "/namespaced/users", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip
      assert_equal %(/*action='index',controller='users',namespaced_controller='name_spaced%2Fusers'*/), comment
    end

    test "controller and namespaced_controller are named correctly, legacy" do
      add_to_config "config.active_record.query_log_tags_enabled = true"
      add_to_config "config.active_record.query_log_tags = [ :action, :namespaced_controller, :controller ]"
      add_to_config "config.active_record.query_log_tags_format = :legacy"

      boot_app

      get "/", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip
      assert_match %(/*action:index,controller:users,namespaced_controller:users*/), comment

      get "/namespaced/users", {}, { "HTTPS" => "on" }
      comment = last_response.body.strip
      assert_match %(/*action:index,controller:users,namespaced_controller:name_spaced/users*/), comment
    end

    private
      def boot_app(env = "production")
        ENV["RAILS_ENV"] = env

        require "#{app_path}/config/environment"
      ensure
        ENV.delete "RAILS_ENV"
      end
  end
end
