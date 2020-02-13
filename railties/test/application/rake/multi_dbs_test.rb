# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  module RakeTests
    class RakeMultiDbsTest < ActiveSupport::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        build_app(multi_db: true)
        FileUtils.rm_rf("#{app_path}/config/environments")
      end

      def teardown
        teardown_app
      end

      def db_create_and_drop(namespace, expected_database)
        Dir.chdir(app_path) do
          output = rails("db:create")
          assert_match(/Created database/, output)
          assert_match_namespace(namespace, output)
          assert_no_match(/already exists/, output)
          assert File.exist?(expected_database)

          output = rails("db:drop")
          assert_match(/Dropped database/, output)
          assert_match_namespace(namespace, output)
          assert_no_match(/does not exist/, output)
          assert_not File.exist?(expected_database)
        end
      end

      def db_create_and_drop_namespace(namespace, expected_database)
        Dir.chdir(app_path) do
          output = rails("db:create:#{namespace}")
          assert_match(/Created database/, output)
          assert_match_namespace(namespace, output)
          assert File.exist?(expected_database)

          output = rails("db:drop:#{namespace}")
          assert_match(/Dropped database/, output)
          assert_match_namespace(namespace, output)
          assert_not File.exist?(expected_database)
        end
      end

      def assert_match_namespace(namespace, output)
        if namespace == "primary"
          assert_match(/#{Rails.env}.sqlite3/, output)
        else
          assert_match(/#{Rails.env}_#{namespace}.sqlite3/, output)
        end
      end

      def db_migrate_and_migrate_status
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate"
          output = rails "db:migrate:status"
          assert_match(/up     \d+  Create books/, output)
          assert_match(/up     \d+  Create dogs/, output)
        end
      end

      def db_migrate_and_schema_cache_dump
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate"
          rails "db:schema:cache:dump"
          assert File.exist?("db/schema_cache.yml")
          assert File.exist?("db/animals_schema_cache.yml")
        end
      end

      def db_migrate_and_schema_cache_dump_and_schema_cache_clear
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate"
          rails "db:schema:cache:dump"
          rails "db:schema:cache:clear"
          assert_not File.exist?("db/schema_cache.yml")
          assert_not File.exist?("db/animals_schema_cache.yml")
        end
      end

      def db_migrate_and_schema_dump_and_load(format)
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate", "db:#{format}:dump"

          if format == "schema"
            schema_dump = File.read("db/#{format}.rb")
            schema_dump_animals = File.read("db/animals_#{format}.rb")
            assert_match(/create_table \"books\"/, schema_dump)
            assert_match(/create_table \"dogs\"/, schema_dump_animals)
          else
            schema_dump = File.read("db/#{format}.sql")
            schema_dump_animals = File.read("db/animals_#{format}.sql")
            assert_match(/CREATE TABLE (?:IF NOT EXISTS )?\"books\"/, schema_dump)
            assert_match(/CREATE TABLE (?:IF NOT EXISTS )?\"dogs\"/, schema_dump_animals)
          end

          rails "db:#{format}:load"

          ar_tables = lambda { rails("runner", "p ActiveRecord::Base.connection.tables").strip }
          animals_tables = lambda { rails("runner", "p AnimalsBase.connection.tables").strip }

          assert_equal '["schema_migrations", "ar_internal_metadata", "books"]', ar_tables[]
          assert_equal '["schema_migrations", "ar_internal_metadata", "dogs"]', animals_tables[]
        end
      end

      def db_migrate_namespaced(namespace)
        Dir.chdir(app_path) do
          generate_models_for_animals
          output = rails("db:migrate:#{namespace}")
          if namespace == "primary"
            assert_match(/CreateBooks: migrated/, output)
          else
            assert_match(/CreateDogs: migrated/, output)
          end
        end
      end

      def db_migrate_status_namespaced(namespace)
        Dir.chdir(app_path) do
          generate_models_for_animals
          output = rails("db:migrate:status:#{namespace}")
          if namespace == "primary"
            assert_match(/up     \d+  Create books/, output)
          else
            assert_match(/up     \d+  Create dogs/, output)
          end
        end
      end

      def db_up_and_down(version, namespace = nil)
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails("db:migrate")

          if namespace
            down_output = rails("db:migrate:down:#{namespace}", "VERSION=#{version}")
            up_output = rails("db:migrate:up:#{namespace}", "VERSION=#{version}")
          else
            assert_raises RuntimeError, /You're using a multiple database application/ do
              down_output = rails("db:migrate:down", "VERSION=#{version}")
            end

            assert_raises RuntimeError, /You're using a multiple database application/ do
              up_output = rails("db:migrate:up", "VERSION=#{version}")
            end
          end

          case namespace
          when "primary"
            assert_match(/OneMigration: reverting/, down_output)
            assert_match(/OneMigration: migrated/, up_output)
          when nil
          else
            assert_match(/TwoMigration: reverting/, down_output)
            assert_match(/TwoMigration: migrated/, up_output)
          end
        end
      end

      def db_prepare
        Dir.chdir(app_path) do
          generate_models_for_animals
          output = rails("db:prepare")

          ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
            if db_config.spec_name == "primary"
              assert_match(/CreateBooks: migrated/, output)
            else
              assert_match(/CreateDogs: migrated/, output)
            end
          end
        end
      end

      def write_models_for_animals
        # make a directory for the animals migration
        FileUtils.mkdir_p("#{app_path}/db/animals_migrate")
        # move the dogs migration if it unless it already lives there
        FileUtils.mv(Dir.glob("#{app_path}/db/migrate/**/*dogs.rb").first, "db/animals_migrate/") unless Dir.glob("#{app_path}/db/animals_migrate/**/*dogs.rb").first
        # delete the dogs migration if it's still present in the
        # migrate folder. This is necessary because sometimes
        # the code isn't fast enough and an extra migration gets made
        FileUtils.rm(Dir.glob("#{app_path}/db/migrate/**/*dogs.rb").first) if Dir.glob("#{app_path}/db/migrate/**/*dogs.rb").first

        # change the base of the dog model
        app_path("/app/models/dog.rb") do |file_name|
          file = File.read("#{app_path}/app/models/dog.rb")
          file.sub!(/ApplicationRecord/, "AnimalsBase")
          File.write(file_name, file)
        end

        # create the base model for dog to inherit from
        File.open("#{app_path}/app/models/animals_base.rb", "w") do |file|
          file.write(<<~EOS)
            class AnimalsBase < ActiveRecord::Base
              self.abstract_class = true

              establish_connection :animals
            end
          EOS
        end
      end

      def generate_models_for_animals
        rails "generate", "model", "book", "title:string"
        rails "generate", "model", "dog", "name:string"
        write_models_for_animals
        reload
      end

      test "db:create and db:drop works on all databases for env" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_create_and_drop db_config.spec_name, db_config.config["database"]
        end
      end

      test "db:create:namespace and db:drop:namespace works on specified databases" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_create_and_drop_namespace db_config.spec_name, db_config.config["database"]
        end
      end

      test "db:migrate set back connection to its original state" do
        Dir.chdir(app_path) do
          dummy_task = <<~RUBY
            task foo: :environment do
              Book.first
            end
          RUBY
          app_file("Rakefile", dummy_task, "a+")

          generate_models_for_animals

          assert_nothing_raised do
            rails("db:migrate", "foo")
          end
        end
      end

      test "db:migrate and db:schema:dump and db:schema:load works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load "schema"
      end

      test "db:migrate and db:structure:dump and db:structure:load works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load "structure"
      end

      test "db:migrate:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_namespaced db_config.spec_name
        end
      end

      test "db:migrate:down and db:migrate:up without a namespace raises in a multi-db application" do
        require "#{app_path}/config/environment"

        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        db_up_and_down "01"
      end

      test "db:migrate:down:namespace and db:migrate:up:namespace works" do
        require "#{app_path}/config/environment"

        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        db_up_and_down "01", "primary"
        db_up_and_down "02", "animals"
      end

      test "db:migrate:status works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_migrate_status
      end

      test "db:migrate:status:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_namespaced db_config.spec_name
          db_migrate_status_namespaced db_config.spec_name
        end
      end

      test "db:schema:cache:dump works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_cache_dump
      end

      # Note that schema cache loader depends on the connection and
      # does not work for all connections.
      test "schema_cache is loaded on primary db in multi-db app" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_cache_dump

        cache_size_a = lambda { rails("runner", "p ActiveRecord::Base.connection.schema_cache.size").strip }
        cache_tables_a = lambda { rails("runner", "p ActiveRecord::Base.connection.schema_cache.columns('books')").strip }
        cache_size_b = lambda { rails("runner", "p AnimalsBase.connection.schema_cache.size").strip }
        cache_tables_b = lambda { rails("runner", "p AnimalsBase.connection.schema_cache.columns('dogs')").strip }

        assert_equal "12", cache_size_a[]
        assert_includes cache_tables_a[], "title", "expected cache_tables_a to include a title entry"

        # Will be 0 because it's not loaded by the railtie
        assert_equal "0", cache_size_b[]
        assert_includes cache_tables_b[], "name", "expected cache_tables_b to include a name entry"
      end

      test "db:schema:cache:clear works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_cache_dump_and_schema_cache_clear
      end

      test "db:abort_if_pending_migrations works on all databases" do
        require "#{app_path}/config/environment"

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        output = rails("db:abort_if_pending_migrations", allow_failure: true)
        assert_match(/You have 1 pending migration/, output)
      end

      test "db:abort_if_pending_migrations:namespace works" do
        require "#{app_path}/config/environment"

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        output = rails("db:abort_if_pending_migrations:primary")
        assert_no_match(/You have \d+ pending migration/, output)
        output = rails("db:abort_if_pending_migrations:animals", allow_failure: true)
        assert_match(/You have 1 pending migration/, output)
      end

      test "db:prepare works on all databases" do
        require "#{app_path}/config/environment"
        db_prepare
      end

      test "db:prepare setups missing database without clearing existing one" do
        require "#{app_path}/config/environment"
        Dir.chdir(app_path) do
          # Bug not visible on SQLite3. Can be simplified when https://github.com/rails/rails/issues/36383 resolved
          use_postgresql(multi_db: true)
          generate_models_for_animals

          rails "db:create:animals", "db:migrate:animals", "db:create:primary", "db:migrate:primary", "db:schema:dump"
          rails "db:drop:primary"
          Dog.create!
          output = rails("db:prepare")

          assert_match(/Created database/, output)
          assert_equal 1, Dog.count
        ensure
          Dog.connection.disconnect!
          rails "db:drop" rescue nil
        end
      end

      test "db:seed uses primary database connection" do
        @old_rails_env = ENV["RAILS_ENV"]
        @old_rack_env = ENV["RACK_ENV"]
        ENV.delete "RAILS_ENV"
        ENV.delete "RACK_ENV"

        db_migrate_and_schema_dump_and_load "schema"

        app_file "db/seeds.rb", <<-RUBY
          print Book.connection.pool.spec.config[:database]
        RUBY

        output = rails("db:seed")
        assert_equal output, "db/development.sqlite3"
      ensure
        ENV["RAILS_ENV"] = @old_rails_env
        ENV["RACK_ENV"] = @old_rack_env
      end
    end
  end
end
