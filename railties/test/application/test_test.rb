# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class TestTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      @old = ENV["PARALLEL_WORKERS"]
      ENV["PARALLEL_WORKERS"] = "0"

      build_app
    end

    def teardown
      ENV["PARALLEL_WORKERS"] = @old

      teardown_app
    end

    test "simple successful test" do
      app_file "test/unit/foo_test.rb", <<-RUBY
        require "test_helper"

        class FooTest < ActiveSupport::TestCase
          def test_truth
            assert true
          end
        end
      RUBY

      assert_successful_test_run "unit/foo_test.rb"
    end

    test "after_run" do
      app_file "test/unit/foo_test.rb", <<-RUBY
        require "test_helper"

        Minitest.after_run { puts "WORLD" }
        Minitest.after_run { puts "HELLO" }

        class FooTest < ActiveSupport::TestCase
          def test_truth
            assert true
          end
        end
      RUBY

      result = assert_successful_test_run "unit/foo_test.rb"
      assert_equal ["HELLO", "WORLD"], result.scan(/HELLO|WORLD/) # only once and in correct order
    end

    test "simple failed test" do
      app_file "test/unit/foo_test.rb", <<-RUBY
        require "test_helper"

        class FooTest < ActiveSupport::TestCase
          def test_truth
            assert false
          end
        end
      RUBY

      assert_unsuccessful_run "unit/foo_test.rb", "Failure:\nFooTest#test_truth"
    end

    test "integration test" do
      controller "posts", <<-RUBY
        class PostsController < ActionController::Base
        end
      RUBY

      app_file "app/views/posts/index.html.erb", <<-HTML
        Posts#index
      HTML

      app_file "test/integration/posts_test.rb", <<-RUBY
        require "test_helper"

        class PostsTest < ActionDispatch::IntegrationTest
          def test_index
            get '/posts'
            assert_response :success
            assert_includes @response.body, 'Posts#index'
          end
        end
      RUBY

      assert_successful_test_run "integration/posts_test.rb"
    end

    test "enable full backtraces on test failures" do
      app_file "test/unit/failing_test.rb", <<-RUBY
        require "test_helper"

        class FailingTest < ActiveSupport::TestCase
          def test_failure
            raise "fail"
          end
        end
      RUBY

      output = run_test_file("unit/failing_test.rb")
      assert_match %r{test/unit/failing_test\.rb}, output
      assert_match %r{test/unit/failing_test\.rb:4}, output
    end

    test "ruby schema migrations" do
      output  = rails("generate", "model", "user", "name:string")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon"
          end
        end
      RUBY
      app_file "db/schema.rb", ""

      assert_unsuccessful_run "models/user_test.rb", "Migrations are pending"

      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      app_file "config/initializers/disable_maintain_test_schema.rb", <<-RUBY
        Rails.application.config.active_record.maintain_test_schema = false
      RUBY

      assert_unsuccessful_run "models/user_test.rb", "Could not find table 'users'"

      File.delete "#{app_path}/config/initializers/disable_maintain_test_schema.rb"

      result = assert_successful_test_run("models/user_test.rb")
      assert_not_includes result, "create_table(:users)"
    end

    test "sql structure migrations" do
      output  = rails("generate", "model", "user", "name:string")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon"
          end
        end
      RUBY

      app_file "db/structure.sql", ""
      app_file "config/initializers/enable_sql_schema_format.rb", <<-RUBY
        Rails.application.config.active_record.schema_format = :sql
      RUBY

      assert_unsuccessful_run "models/user_test.rb", "Migrations are pending"

      app_file "db/structure.sql", <<-SQL
        CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL);
        CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version");
        CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255));
        INSERT INTO schema_migrations (version) VALUES ('#{version}');
      SQL

      app_file "config/initializers/disable_maintain_test_schema.rb", <<-RUBY
        Rails.application.config.active_record.maintain_test_schema = false
      RUBY

      assert_unsuccessful_run "models/user_test.rb", "Could not find table 'users'"

      File.delete "#{app_path}/config/initializers/disable_maintain_test_schema.rb"

      assert_successful_test_run("models/user_test.rb")
    end

    test "sql structure migrations when adding column to existing table" do
      output_1  = rails("generate", "model", "user", "name:string")
      version_1 = output_1.match(/(\d+)_create_users\.rb/)[1]

      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"
        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon"
          end
        end
      RUBY

      app_file "config/initializers/enable_sql_schema_format.rb", <<-RUBY
        Rails.application.config.active_record.schema_format = :sql
      RUBY

      app_file "db/structure.sql", <<-SQL
        CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL);
        CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version");
        CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255));
        INSERT INTO schema_migrations (version) VALUES ('#{version_1}');
      SQL

      assert_successful_test_run("models/user_test.rb")

      output_2  = rails("generate", "migration", "add_email_to_users")
      version_2 = output_2.match(/(\d+)_add_email_to_users\.rb/)[1]

      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon", email: "jon@doe.com"
          end
        end
      RUBY

      app_file "db/structure.sql", <<-SQL
        CREATE TABLE "schema_migrations" ("version" varchar(255) NOT NULL);
        CREATE UNIQUE INDEX "unique_schema_migrations" ON "schema_migrations" ("version");
        CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255), "email" varchar(255));
        INSERT INTO schema_migrations (version) VALUES ('#{version_1}');
        INSERT INTO schema_migrations (version) VALUES ('#{version_2}');
      SQL

      assert_successful_test_run("models/user_test.rb")
    end

    test "automatically synchronizes test schema after rollback" do
      output  = rails("generate", "model", "user", "name:string")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"

        class UserTest < ActiveSupport::TestCase
          test "user" do
            assert_equal ["id", "name"], User.columns_hash.keys
          end
        end
      RUBY
      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      assert_successful_test_run "models/user_test.rb"

      # Simulate `db:rollback` + edit of the migration file + `db:migrate`
      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
            t.integer :age
          end
        end
      RUBY

      assert_unsuccessful_run "models/user_test.rb", <<-ASSERTION
Expected: ["id", "name"]
  Actual: ["id", "name", "age"]
      ASSERTION
    end

    test "hooks for plugins" do
      output  = rails("generate", "model", "user", "name:string")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "lib/tasks/hooks.rake", <<-RUBY
        task :before_hook do
          has_user_table = ActiveRecord::Base.lease_connection.table_exists?('users')
          puts "before: " + has_user_table.to_s
        end

        task :after_hook do
          has_user_table = ActiveRecord::Base.lease_connection.table_exists?('users')
          puts "after: " + has_user_table.to_s
        end

        Rake::Task["db:test:prepare"].enhance [:before_hook] do
          Rake::Task[:after_hook].invoke
        end
      RUBY
      app_file "test/models/user_test.rb", <<-RUBY
        require "test_helper"
        class UserTest < ActiveSupport::TestCase
          test "user" do
            User.create! name: "Jon"
          end
        end
      RUBY

      # Simulate `db:migrate`
      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      output = assert_successful_test_run "models/user_test.rb"
      assert_includes output, "before: false\nafter: true"

      # running tests again won't trigger a schema update
      output = assert_successful_test_run "models/user_test.rb"
      assert_not_includes output, "before:"
      assert_not_includes output, "after:"
    end

    test "schema for all the models is loaded when tests are run in eager load context" do
      output = rails("generate", "model", "user", "name:string")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "db/schema.rb", <<-RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_table :users do |t|
            t.string :name
          end
        end
      RUBY

      app_file "config/initializers/enable_eager_load.rb", <<-RUBY
        Rails.application.config.eager_load = true
      RUBY

      app_file "app/models/user.rb", <<-RUBY
        class User < ApplicationRecord
          def self.load_schema!
            super
            raise "SCHEMA LOADED!"
          end
        end
      RUBY

      assert_unsuccessful_run "models/user_test.rb", "SCHEMA LOADED!"
    end

    test "database-dependent attribute types are resolved when parallel tests are run in eager load context" do
      use_postgresql
      rails "db:drop", "db:create"

      output = rails("generate", "model", "user")
      version = output.match(/(\d+)_create_users\.rb/)[1]

      app_file "db/schema.rb", <<~RUBY
        ActiveRecord::Schema.define(version: #{version}) do
          create_enum "user_favorite_color", ["red", "green", "blue"]

          create_table :users do |t|
            t.enum :favorite_color, enum_type: :user_favorite_color
          end
        end
      RUBY

      app_file "config/initializers/enable_eager_load.rb", <<~RUBY
        Rails.application.config.eager_load = true
      RUBY

      app_file "test/models/user_test.rb", <<~RUBY
        require "test_helper"
        class UserTest < ActiveSupport::TestCase
          ENV.delete("PARALLEL_WORKERS")
          parallelize threshold: 1, workers: 2

          2.times do |i|
            test "favorite_color uses database type (worker \#{i})" do
              assert_instance_of ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Enum, User.type_for_attribute("favorite_color")
            end
          end
        end
      RUBY

      assert_successful_test_run "models/user_test.rb"
    ensure
      rails "db:drop" rescue nil
    end

    private
      def assert_unsuccessful_run(name, message)
        result = run_test_file(name)
        assert_not_equal 0, $?.to_i
        assert_includes result, message
        result
      end

      def assert_successful_test_run(name)
        result = run_test_file(name)
        assert_equal 0, $?.to_i, result
        result
      end

      def run_test_file(name)
        rails "test", "#{app_path}/test/#{name}", allow_failure: true
      end
  end
end
