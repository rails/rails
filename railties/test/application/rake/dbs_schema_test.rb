# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeDbsSchemaTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app
        reset_environment_configs
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

      def db_migrate_and_status(expected_database)
        rails "generate", "model", "book", "title:string"
        rails "db:migrate"
        output = rails("db:migrate:status")
        assert_match(%r{database:\s+\S*#{Regexp.escape(expected_database)}}, output)
        assert_match(/up\s+\d{14}\s+Create books/, output)
      end

      test "db:migrate and db:migrate:status without database_url" do
        require "#{app_path}/config/environment"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
        db_migrate_and_status db_config.database
      end

      test "db:migrate and db:migrate:status with database_url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_migrate_and_status database_url_db_name
      end

      test "db:migrate on new db loads schema" do
        app_file "db/schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20140423102712) do
            create_table(:comments) {}
          end
        RUBY

        rails "db:migrate"
        list_tables = lambda { rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip }

        assert_equal "[\"ar_internal_metadata\", \"comments\", \"schema_migrations\"]", list_tables[]
      end

      test "db:migrate on multiple new dbs loads schema" do
        File.write("#{app_path}/config/database.yml", <<~YAML)
          development:
            primary:
              adapter: sqlite3
              database: storage/test.sqlite3
            queue:
              adapter: sqlite3
              database: storage/test_queue.sqlite3
        YAML

        app_file "db/schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20140423102712) do
            create_table(:comments) {}
          end
        RUBY

        app_file "db/queue_schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20141016001513) do
            create_table(:executions) {}
          end
        RUBY

        rails "db:migrate"
        primary_tables = lambda { rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip }
        queue_tables = lambda { rails("runner", "p ActiveRecord::Base.connects_to(database: { writing: :queue }).first.lease_connection.tables.sort").strip }

        assert_equal "[\"ar_internal_metadata\", \"comments\", \"schema_migrations\"]", primary_tables[]
        assert_equal "[\"ar_internal_metadata\", \"executions\", \"schema_migrations\"]", queue_tables[]
      end

      test "db:migrate:reset regenerates the schema from migrations" do
        app_file "db/migrate/01_a_migration.rb", <<-MIGRATION
          class AMigration < ActiveRecord::Migration::Current
             create_table(:comments) {}
          end
        MIGRATION
        rails("db:migrate")
        app_file "db/migrate/01_a_migration.rb", <<-MIGRATION
          class AMigration < ActiveRecord::Migration::Current
             create_table(:comments) { |t| t.string :title }
          end
        MIGRATION

        rails("db:migrate:reset")

        assert File.read("#{app_path}/db/schema.rb").include?("title")
      end

      def db_schema_dump
        Dir.chdir(app_path) do
          args = ["generate", "model", "book", "title:string"]
          rails args
          rails "db:migrate", "db:schema:dump"
          assert_match(/create_table "books"/, File.read("db/schema.rb"))
        end
      end

      def db_schema_sql_dump
        Dir.chdir(app_path) do
          args = ["generate", "model", "book", "title:string"]
          rails args
          rails "db:migrate", "db:schema:dump"
          assert_match(/CREATE TABLE/, File.read("db/structure.sql"))
        end
      end

      test "db:schema:dump without database_url" do
        db_schema_dump
      end

      test "db:schema:dump with database_url" do
        set_database_url
        db_schema_dump
      end

      test "db:schema:dump with env as ruby" do
        add_to_config "config.active_record.schema_format = :sql"

        old_env = ENV["SCHEMA_FORMAT"]
        ENV["SCHEMA_FORMAT"] = "ruby"

        db_schema_dump
      ensure
        ENV["SCHEMA_FORMAT"] = old_env
      end

      test "db:schema:dump with env as sql" do
        add_to_config "config.active_record.schema_format = :ruby"

        old_env = ENV["SCHEMA_FORMAT"]
        ENV["SCHEMA_FORMAT"] = "sql"

        db_schema_sql_dump
      ensure
        ENV["SCHEMA_FORMAT"] = old_env
      end

      def db_schema_cache_dump
        Dir.chdir(app_path) do
          rails "db:schema:cache:dump"

          cache_size = lambda { rails("runner", "p ActiveRecord::Base.schema_cache.size").strip }
          cache_tables = lambda { rails("runner", "p ActiveRecord::Base.schema_cache.columns('books')").strip }

          assert_equal "12", cache_size[]
          assert_includes cache_tables[], "id", "expected cache_tables to include an id entry"
          assert_includes cache_tables[], "title", "expected cache_tables to include a title entry"
        end
      end

      test "db:schema:cache:dump" do
        db_schema_dump
        db_schema_cache_dump
      end

      test "db:schema:cache:dump with custom filename" do
        Dir.chdir(app_path) do
          File.open("#{app_path}/config/database.yml", "w") do |f|
            f.puts <<-YAML
            default: &default
              adapter: sqlite3
              max_connections: 5
              timeout: 5000
              variables:
                statement_timeout: 1000
            development:
              <<: *default
              database: storage/development.sqlite3
              schema_cache_path: db/special_schema_cache.yml
            YAML
          end
        end

        db_schema_dump
        db_schema_cache_dump
      end

      test "db:schema:cache:dump first config wins" do
        Dir.chdir(app_path) do
          File.open("#{app_path}/config/database.yml", "w") do |f|
            f.puts <<-YAML
            default: &default
              adapter: sqlite3
              max_connections: 5
              timeout: 5000
              variables:
                statement_timeout: 1000
            development:
              some_entry:
                <<: *default
                database: storage/development.sqlite3
              another_entry:
                <<: *default
                database: db/another_entry_development.sqlite3
                migrations_paths: db/another_entry_migrate
            YAML
          end
        end

        db_schema_dump
        db_schema_cache_dump
      end

      test "db:schema:cache:dump ignores expired version" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:schema:cache:dump"
          rails "generate", "model", "cat", "color:string"
          rails "db:migrate"

          expired_warning = capture(:stderr) do
            cache_size = rails("runner", "p ActiveRecord::Base.schema_cache.size", stderr: true).strip
            assert_equal "0", cache_size
          end
          assert_match(/Ignoring .*\.yml because it has expired/, expired_warning)
        end
      end

      def db_fixtures_load(expected_database)
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          reload
          rails "db:migrate", "db:fixtures:load"

          assert_match expected_database, ActiveRecord::Base.connection_db_config.database
          assert_equal 2, Book.count
        end
      end

      test "db:fixtures:load without database_url" do
        require "#{app_path}/config/environment"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
        db_fixtures_load db_config.database
      end

      test "db:fixtures:load with database_url" do
        require "#{app_path}/config/environment"
        set_database_url
        db_fixtures_load database_url_db_name
      end

      test "db:fixtures:load with namespaced fixture" do
        require "#{app_path}/config/environment"

        rails "generate", "model", "admin::book", "title:string"
        reload
        rails "db:migrate", "db:fixtures:load"

        assert_equal 2, Admin::Book.count
      end

      test "db:schema:load does not purge the existing database" do
        rails "runner", "ActiveRecord::Base.lease_connection.create_table(:posts) {|t| t.string :title }"

        app_file "db/schema.rb", <<-RUBY
          ActiveRecord::Schema.define(version: 20140423102712) do
            create_table(:comments) {}
          end
        RUBY

        list_tables = lambda { rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip }

        assert_equal '["posts"]', list_tables[]
        rails "db:schema:load"
        assert_equal '["ar_internal_metadata", "comments", "posts", "schema_migrations"]', list_tables[]

        add_to_config "config.active_record.schema_format = :sql"
        app_file "db/structure.sql", <<-SQL
          CREATE TABLE "users" ("id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar(255));
        SQL

        rails "db:schema:load"
        assert_equal '["ar_internal_metadata", "comments", "posts", "schema_migrations", "users"]', list_tables[]
      end

      test "db:schema:load with inflections" do
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

        rails "db:schema:load"

        tables = rails("runner", "p ActiveRecord::Base.lease_connection.tables").strip
        assert_match(/"geese"/, tables)

        columns = rails("runner", "p ActiveRecord::Base.lease_connection.columns('geese').map(&:name)").strip
        assert_equal '["gooseid", "name"]', columns
      end

      test "db:schema:load fails if schema.rb doesn't exist yet" do
        stderr_output = capture(:stderr) { rails("db:schema:load", stderr: true, allow_failure: true) }
        assert_match(/Run `bin\/rails db:migrate` to create it/, stderr_output)
      end
    end
  end
end
