require "isolation/abstract_unit"
require "active_support/core_ext/string/strip"

module ApplicationTests
  module RakeTests
    class RakeDbsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
      end

      def database_url_db_name
        "db/database_url_db.sqlite3"
      end

      def set_database_url
        ENV["DATABASE_URL"] = "sqlite3:#{database_url_db_name}"
        # ensure it's using the DATABASE_URL
        FileUtils.rm_rf("#{app_path}/config/database.yml")
      end

      def db_create_and_drop(expected_database)
        Dir.chdir(app_path) do
          output = `bin/rails db:create`
          assert_match(/Created database/, output)
          assert File.exist?(expected_database)
          assert_equal expected_database, ActiveRecord::Base.connection_config[:database]
          output = `bin/rails db:drop`
          assert_match(/Dropped database/, output)
          assert !File.exist?(expected_database)
        end
      end

      test "db:create and db:drop without database url" do
        require "#{app_path}/config/environment"
        db_create_and_drop ActiveRecord::Base.configurations[Rails.env]["database"]
      end

      test "db:create and db:drop with database url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_create_and_drop database_url_db_name
      end

      def with_database_existing
        Dir.chdir(app_path) do
          set_database_url
          `bin/rails db:create`
          yield
          `bin/rails db:drop`
        end
      end

      test "db:create failure because database exists" do
        with_database_existing do
          output = `bin/rails db:create 2>&1`
          assert_match(/already exists/, output)
          assert_equal 0, $?.exitstatus
        end
      end

      def with_bad_permissions
        Dir.chdir(app_path) do
          set_database_url
          FileUtils.chmod("-w", "db")
          yield
          FileUtils.chmod("+w", "db")
        end
      end

      test "db:create failure because bad permissions" do
        with_bad_permissions do
          output = `bin/rails db:create 2>&1`
          assert_match(/Couldn't create database/, output)
          assert_equal 1, $?.exitstatus
        end
      end

      test "db:drop failure because database does not exist" do
        Dir.chdir(app_path) do
          output = `bin/rails db:drop:_unsafe --trace 2>&1`
          assert_match(/does not exist/, output)
          assert_equal 0, $?.exitstatus
        end
      end

      test "db:drop failure because bad permissions" do
        with_database_existing do
          with_bad_permissions do
            output = `bin/rails db:drop 2>&1`
            assert_match(/Couldn't drop/, output)
            assert_equal 1, $?.exitstatus
          end
        end
      end

      def db_migrate_and_status(expected_database)
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate`
          output = `bin/rails db:migrate:status`
          assert_match(%r{database:\s+\S*#{Regexp.escape(expected_database)}}, output)
          assert_match(/up\s+\d{14}\s+Create books/, output)
        end
      end

      test "db:migrate and db:migrate:status without database_url" do
        require "#{app_path}/config/environment"
        db_migrate_and_status ActiveRecord::Base.configurations[Rails.env]["database"]
      end

      test "db:migrate and db:migrate:status with database_url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_migrate_and_status database_url_db_name
      end

      def db_schema_dump
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate db:schema:dump`
          schema_dump = File.read("db/schema.rb")
          assert_match(/create_table \"books\"/, schema_dump)
        end
      end

      test "db:schema:dump without database_url" do
        db_schema_dump
      end

      test "db:schema:dump with database_url" do
        set_database_url
        db_schema_dump
      end

      def db_fixtures_load(expected_database)
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate db:fixtures:load`
          assert_match expected_database, ActiveRecord::Base.connection_config[:database]
          require "#{app_path}/app/models/book"
          assert_equal 2, Book.count
        end
      end

      test "db:fixtures:load without database_url" do
        require "#{app_path}/config/environment"
        db_fixtures_load ActiveRecord::Base.configurations[Rails.env]["database"]
      end

      test "db:fixtures:load with database_url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_fixtures_load database_url_db_name
      end

      test "db:fixtures:load with namespaced fixture" do
        require "#{app_path}/config/environment"
        Dir.chdir(app_path) do
          `bin/rails generate model admin::book title:string;
           bin/rails db:migrate db:fixtures:load`
          require "#{app_path}/app/models/admin/book"
          assert_equal 2, Admin::Book.count
        end
      end

      def db_structure_dump_and_load(expected_database)
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate db:structure:dump`
          structure_dump = File.read("db/structure.sql")
          assert_match(/CREATE TABLE \"books\"/, structure_dump)
          `bin/rails environment db:drop db:structure:load`
          assert_match expected_database, ActiveRecord::Base.connection_config[:database]
          require "#{app_path}/app/models/book"
          #if structure is not loaded correctly, exception would be raised
          assert_equal 0, Book.count
        end
      end

      test "db:structure:dump and db:structure:load without database_url" do
        require "#{app_path}/config/environment"
        db_structure_dump_and_load ActiveRecord::Base.configurations[Rails.env]["database"]
      end

      test "db:structure:dump and db:structure:load with database_url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_structure_dump_and_load database_url_db_name
      end

      test "db:structure:dump does not dump schema information when no migrations are used" do
        Dir.chdir(app_path) do
          # create table without migrations
          `bin/rails runner 'ActiveRecord::Base.connection.create_table(:posts) {|t| t.string :title }'`

          stderr_output = capture(:stderr) { `bin/rails db:structure:dump` }
          assert_empty stderr_output
          structure_dump = File.read("db/structure.sql")
          assert_match(/CREATE TABLE \"posts\"/, structure_dump)
        end
      end

      test "db:schema:load and db:structure:load do not purge the existing database" do
        Dir.chdir(app_path) do
          `bin/rails runner 'ActiveRecord::Base.connection.create_table(:posts) {|t| t.string :title }'`

          app_file "db/schema.rb", <<-RUBY
            ActiveRecord::Schema.define(version: 20140423102712) do
              create_table(:comments) {}
            end
          RUBY

          list_tables = lambda { `bin/rails runner 'p ActiveRecord::Base.connection.tables'`.strip }

          assert_equal '["posts"]', list_tables[]
          `bin/rails db:schema:load`
          assert_equal '["posts", "comments", "schema_migrations", "ar_internal_metadata"]', list_tables[]

          app_file "db/structure.sql", <<-SQL
            CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255));
          SQL

          `bin/rails db:structure:load`
          assert_equal '["posts", "comments", "schema_migrations", "ar_internal_metadata", "users"]', list_tables[]
        end
      end

      test "db:schema:load with inflections" do
        Dir.chdir(app_path) do
          app_file "config/initializers/inflection.rb", <<-RUBY
            ActiveSupport::Inflector.inflections do |inflect|
              inflect.irregular 'goose', 'geese'
            end
          RUBY
          app_file "config/initializers/primary_key_table_name.rb", <<-RUBY
            ActiveRecord::Base.primary_key_prefix_type = :table_name
          RUBY
          app_file "db/schema.rb", <<-RUBY
            ActiveRecord::Schema.define(version: 20140423102712) do
              create_table("goose".pluralize) do |t|
                t.string :name
              end
            end
          RUBY

          `bin/rails db:schema:load`

          tables = `bin/rails runner 'p ActiveRecord::Base.connection.tables'`.strip
          assert_match(/"geese"/, tables)

          columns = `bin/rails runner 'p ActiveRecord::Base.connection.columns("geese").map(&:name)'`.strip
          assert_equal columns, '["gooseid", "name"]'
        end
      end

      def db_test_load_structure
        Dir.chdir(app_path) do
          `bin/rails generate model book title:string;
           bin/rails db:migrate db:structure:dump db:test:load_structure`
          ActiveRecord::Base.configurations = Rails.application.config.database_configuration
          ActiveRecord::Base.establish_connection :test
          require "#{app_path}/app/models/book"
          #if structure is not loaded correctly, exception would be raised
          assert_equal 0, Book.count
          assert_match ActiveRecord::Base.configurations["test"]["database"],
            ActiveRecord::Base.connection_config[:database]
        end
      end

      test "db:test:load_structure without database_url" do
        require "#{app_path}/config/environment"
        db_test_load_structure
      end

      test "db:setup loads schema and seeds database" do
        begin
          @old_rails_env = ENV["RAILS_ENV"]
          @old_rack_env = ENV["RACK_ENV"]
          ENV.delete "RAILS_ENV"
          ENV.delete "RACK_ENV"

          app_file "db/schema.rb", <<-RUBY
            ActiveRecord::Schema.define(version: "1") do
              create_table :users do |t|
                t.string :name
              end
            end
          RUBY

          app_file "db/seeds.rb", <<-RUBY
            puts ActiveRecord::Base.connection_config[:database]
          RUBY

          Dir.chdir(app_path) do
            database_path = `bin/rails db:setup`
            assert_equal "development.sqlite3", File.basename(database_path.strip)
          end
        ensure
          ENV["RAILS_ENV"] = @old_rails_env
          ENV["RACK_ENV"] = @old_rack_env
        end
      end
    end
  end
end
