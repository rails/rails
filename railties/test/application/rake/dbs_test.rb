# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  module RakeTests
    class RakeDbsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation, EnvHelpers

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

      def db_create_and_drop(expected_database, environment_loaded: true)
        Dir.chdir(app_path) do
          output = rails("db:create")
          assert_match(/Created database/, output)
          assert File.exist?(expected_database)
          yield if block_given?
          assert_equal expected_database, ActiveRecord::Base.connection_db_config.database if environment_loaded
          output = rails("db:drop")
          assert_match(/Dropped database/, output)
          assert_not File.exist?(expected_database)
        end
      end

      test "db:create and db:drop without database URL" do
        require "#{app_path}/config/environment"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: "primary")
        db_create_and_drop db_config.database
      end

      test "db:create and db:drop with database URL" do
        require "#{app_path}/config/environment"
        set_database_url
        db_create_and_drop database_url_db_name
      end

      test "db:create and db:drop with database URL don't use YAML DBs" do
        require "#{app_path}/config/environment"
        set_database_url

        File.write("#{app_path}/config/database.yml", <<~YAML)
          test:
            adapter: sqlite3
            database: storage/test.sqlite3

          development:
            adapter: sqlite3
            database: storage/development.sqlite3
        YAML

        with_rails_env "development" do
          db_create_and_drop database_url_db_name do
            assert_not File.exist?("#{app_path}/storage/test.sqlite3")
            assert_not File.exist?("#{app_path}/storage/development.sqlite3")
          end
        end
      end

      test "db:create and db:drop respect environment setting" do
        app_file "config/database.yml", <<-YAML
          <% 1 %>
          development:
            database: <%= Rails.application.config.database %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML with alias ERB" do
        app_file "config/database.yml", <<-YAML
          sqlite: &sqlite
            adapter: sqlite3
            database: storage/development.sqlite3

          development:
            <<: *<%= ENV["DB"] || "sqlite" %>
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML with multiline ERB" do
        app_file "config/database.yml", <<-YAML
          development:
            database: <%=
              Rails.application.config.database
            %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading ERB accessing nested configurations" do
        app_file "config/database.yml", <<-YAML
          development:
            database: storage/development.sqlite3
            adapter: sqlite3
            other: <%= Rails.application.config.other.value %>
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.other = Struct.new(:value).new(123)
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML containing conditional statements in ERB" do
        app_file "config/database.yml", <<-YAML
          development:
          <% if Rails.application.config.database %>
            database: <%= Rails.application.config.database %>
          <% else %>
            database: db/default.sqlite3
          <% end %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML containing multiple ERB statements on the same line" do
        app_file "config/database.yml", <<-YAML
          development:
            database: <% if Rails.application.config.database %><%= Rails.application.config.database %><% else %>db/default.sqlite3<% end %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML with single-line ERB" do
        app_file "config/database.yml", <<-YAML
          development:
            <%= Rails.application.config.database ? 'database: storage/development.sqlite3' : 'database: storage/development.sqlite3' %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      test "db:create and db:drop don't raise errors when loading YAML which contains a key's value as an ERB statement" do
        app_file "config/database.yml", <<-YAML
          development:
            database: <%= Rails.application.config.database ? 'storage/development.sqlite3' : 'storage/development.sqlite3' %>
            custom_option: <%= ENV['CUSTOM_OPTION'] %>
            adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "storage/development.sqlite3"
          end
        RUBY

        db_create_and_drop("storage/development.sqlite3", environment_loaded: false)
      end

      def with_database_existing
        Dir.chdir(app_path) do
          set_database_url
          rails "db:create"
          yield
          rails "db:drop"
        end
      end

      test "db:create failure because database exists" do
        with_database_existing do
          output = rails("db:create")
          assert_match(/already exists/, output)
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

      unless Process.uid.zero?
        test "db:create failure because bad permissions" do
          with_bad_permissions do
            output = rails("db:create", allow_failure: true)
            assert_match("Couldn't create '#{database_url_db_name}' database. Please check your configuration.", output)
            assert_equal 1, $?.exitstatus
          end
        end

        test "db:drop failure because bad permissions" do
          with_database_existing do
            with_bad_permissions do
              output = rails("db:drop", allow_failure: true)
              assert_match(/Couldn't drop/, output)
              assert_equal 1, $?.exitstatus
            end
          end
        end
      end
      test "db:create works when schema cache exists and database does not exist" do
        use_postgresql

        begin
          rails %w(db:create db:migrate db:schema:cache:dump)

          rails "db:drop"
          rails "db:create"
          assert_equal 0, $?.exitstatus
        ensure
          rails "db:drop" rescue nil
        end
      end

      test "db:drop failure because database does not exist" do
        output = rails("db:drop:_unsafe", "--trace")
        assert_match(/does not exist/, output)
      end

      test "db:truncate_all truncates all non-internal tables" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"
          require "#{app_path}/config/environment"
          Book.create!(title: "Remote")
          assert_equal 1, Book.count
          schema_migrations = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
          internal_metadata = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")

          rails "db:truncate_all"

          assert_equal(
            schema_migrations,
            ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
          )
          assert_equal(
            internal_metadata,
            ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
          )
          assert_equal 0, Book.count
        end
      end

      test "db:truncate_all does not truncate any tables when environment is protected" do
        with_rails_env "production" do
          Dir.chdir(app_path) do
            rails "generate", "model", "book", "title:string"
            rails "db:migrate"
            require "#{app_path}/config/environment"
            Book.create!(title: "Remote")
            assert_equal 1, Book.count
            schema_migrations = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
            internal_metadata = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
            books = ActiveRecord::Base.lease_connection.execute("SELECT * from \"books\"")

            output = rails("db:truncate_all", allow_failure: true)
            assert_match(/ActiveRecord::ProtectedEnvironmentError/, output)

            assert_equal(
              schema_migrations,
              ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
            )
            assert_equal(
              internal_metadata,
              ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
            )
            assert_equal 1, Book.count
            assert_equal(books, ActiveRecord::Base.lease_connection.execute("SELECT * from \"books\""))
          end
        end
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
              pool: 5
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
              pool: 5
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

      test "db:schema:cache:dump dumps virtual columns" do
        Dir.chdir(app_path) do
          use_postgresql
          rails "db:drop", "db:create"

          rails "runner", <<~RUBY
            ActiveRecord::Base.lease_connection.create_table(:books) do |t|
              t.integer :pages
              t.virtual :pages_plus_1, type: :integer, as: "pages + 1", stored: true
            end
          RUBY

          rails "db:schema:cache:dump"

          virtual_column_exists = rails("runner", "p ActiveRecord::Base.schema_cache.columns('books')[2].virtual?").strip
          assert_equal "true", virtual_column_exists
        end
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

      test "db:setup loads schema and seeds database" do
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
          puts ActiveRecord::Base.connection_db_config.database
        RUBY

        database_path = rails("db:setup")
        assert_equal "development.sqlite3", File.basename(database_path.strip)
      ensure
        ENV["RAILS_ENV"] = @old_rails_env
        ENV["RACK_ENV"] = @old_rack_env
      end

      test "db:setup sets ar_internal_metadata" do
        app_file "db/schema.rb", ""
        rails "db:setup"

        test_environment = lambda { rails("runner", "-e", "test", "puts ActiveRecord::Base.connection_pool.internal_metadata[:environment]").strip }
        development_environment = lambda { rails("runner", "puts ActiveRecord::Base.connection_pool.internal_metadata[:environment]").strip }

        assert_equal "test", test_environment.call
        assert_equal "development", development_environment.call

        app_file "db/structure.sql", ""
        app_file "config/initializers/enable_sql_schema_format.rb", <<-RUBY
          Rails.application.config.active_record.schema_format = :sql
        RUBY

        rails "db:setup"

        assert_equal "test", test_environment.call
        assert_equal "development", development_environment.call
      end

      test "db:test:prepare sets test ar_internal_metadata" do
        app_file "db/schema.rb", ""
        rails "db:test:prepare"

        test_environment = lambda { rails("runner", "-e", "test", "puts ActiveRecord::Base.connection_pool.internal_metadata[:environment]").strip }

        assert_equal "test", test_environment.call

        app_file "db/structure.sql", ""
        app_file "config/initializers/enable_sql_schema_format.rb", <<-RUBY
          Rails.application.config.active_record.schema_format = :sql
        RUBY

        rails "db:test:prepare"

        assert_equal "test", test_environment.call
      end

      test "db:seed:replant truncates all non-internal tables and loads the seeds" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"
          require "#{app_path}/config/environment"
          Book.create!(title: "Remote")
          assert_equal 1, Book.count
          schema_migrations = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
          internal_metadata = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")

          app_file "db/seeds.rb", <<-RUBY
            Book.create!(title: "Rework")
            Book.create!(title: "Ruby Under a Microscope")
          RUBY

          rails "db:seed:replant"

          assert_equal(
            schema_migrations,
            ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
          )
          assert_equal(
            internal_metadata,
            ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
          )
          assert_equal 2, Book.count
          assert_not_predicate Book.where(title: "Remote"), :exists?
          assert_predicate Book.where(title: "Rework"), :exists?
          assert_predicate Book.where(title: "Ruby Under a Microscope"), :exists?
        end
      end

      test "db:seed:replant does not truncate any tables and does not load the seeds when environment is protected" do
        with_rails_env "production" do
          Dir.chdir(app_path) do
            rails "generate", "model", "book", "title:string"
            rails "db:migrate"
            require "#{app_path}/config/environment"
            Book.create!(title: "Remote")
            assert_equal 1, Book.count
            schema_migrations = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
            internal_metadata = ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
            books = ActiveRecord::Base.lease_connection.execute("SELECT * from \"books\"")

            app_file "db/seeds.rb", <<-RUBY
              Book.create!(title: "Rework")
            RUBY

            output = rails("db:seed:replant", allow_failure: true)
            assert_match(/ActiveRecord::ProtectedEnvironmentError/, output)

            assert_equal(
              schema_migrations,
              ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.schema_migrations_table_name}\"")
            )
            assert_equal(
              internal_metadata,
              ActiveRecord::Base.lease_connection.execute("SELECT * from \"#{ActiveRecord::Base.internal_metadata_table_name}\"")
            )
            assert_equal 1, Book.count
            assert_equal(books, ActiveRecord::Base.lease_connection.execute("SELECT * from \"books\""))
            assert_not_predicate Book.where(title: "Rework"), :exists?
          end
        end
      end

      test "db:prepare loads schema, runs pending migrations, and updates schema" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          output = rails("db:prepare")
          assert_match(/CreateBooks: migrated/, output)
          assert_match(/create_table "books"/, File.read("db/schema.rb"))

          output = rails("db:drop")
          assert_match(/Dropped database/, output)

          rails "generate", "model", "recipe", "title:string"
          output = rails("db:prepare")
          assert_no_match(/CreateBooks: migrated/, output) # loaded from schema
          assert_match(/CreateRecipes: migrated/, output)

          schema = File.read("db/schema.rb")
          assert_match(/create_table "books"/, schema)
          assert_match(/create_table "recipes"/, schema)

          tables = rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip
          assert_equal('["ar_internal_metadata", "books", "recipes", "schema_migrations"]', tables)

          test_environment = lambda { rails("runner", "-e", "test", "puts ActiveRecord::Base.connection_pool.internal_metadata[:environment]").strip }
          development_environment = lambda { rails("runner", "puts ActiveRecord::Base.connection_pool.internal_metadata[:environment]").strip }

          assert_equal "development", development_environment.call
          assert_equal "test", test_environment.call
        end
      end

      test "db:prepare loads schema when database exists but is empty" do
        rails "generate", "model", "book", "title:string"
        rails("db:prepare", "db:drop", "db:create")

        output = rails("db:prepare")
        assert_no_match(/CreateBooks: migrated/, output)

        tables = rails("runner", "p ActiveRecord::Base.lease_connection.tables.sort").strip
        assert_equal('["ar_internal_metadata", "books", "schema_migrations"]', tables)
      end

      test "db:prepare does not dump schema when dumping is disabled" do
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:create", "db:migrate"

          app_file "db/schema.rb", "# Not touched"
          app_file "config/initializers/disable_dumping_schema.rb", <<-RUBY
            Rails.application.config.active_record.dump_schema_after_migration = false
          RUBY

          rails "db:prepare"

          assert_equal("# Not touched", File.read("db/schema.rb").strip)
        end
      end

      test "db:prepare creates test database if it does not exist" do
        Dir.chdir(app_path) do
          db_name = use_postgresql
          rails "db:drop", "db:create"
          rails "runner", "ActiveRecord::Base.lease_connection.drop_database(:#{db_name}_test)"

          output = rails("db:prepare")
          assert_match(%r{Created database '#{db_name}_test'}, output)
        end
      ensure
        rails "db:drop" rescue nil
      end

      test "lazily loaded schema cache isn't read when reading the schema migrations table" do
        Dir.chdir(app_path) do
          app_file "config/initializers/lazy_load_schema_cache.rb", <<-RUBY
            Rails.application.config.active_record.lazily_load_schema_cache = true
          RUBY

          rails "generate", "model", "recipe", "title:string"
          rails "db:migrate"
          rails "db:schema:cache:dump"

          file = File.read("db/schema_cache.yml")
          assert_match(/schema_migrations: true/, file)
          assert_match(/recipes: true/, file)

          output = rails "db:drop"
          assert_match(/Dropped database/, output)

          repeat_output = rails "db:drop"
          assert_match(/Dropped database/, repeat_output)
        end
      end

      test "destructive tasks are protected" do
        add_to_config "config.active_record.protected_environments = ['development', 'test']"

        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          destructive_tasks = ["db:drop:all", "db:drop", "db:purge:all", "db:truncate_all", "db:purge", "db:schema:load", "db:test:purge"]

          destructive_tasks.each do |task|
            error = assert_raises("#{task} did not raise ActiveRecord::ProtectedEnvironmentError") { rails task }
            assert_match(/ActiveRecord::ProtectedEnvironmentError/, error.message)
          end
        end
      end
    end
  end
end
