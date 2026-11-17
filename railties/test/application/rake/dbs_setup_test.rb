# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"

module ApplicationTests
  module RakeTests
    class RakeDbsSetupTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation, EnvHelpers

      def setup
        build_app
        reset_environment_configs
      end

      def teardown
        teardown_app
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
