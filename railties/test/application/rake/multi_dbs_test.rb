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

      def db_migrate_and_schema_dump_and_load(schema_format = "ruby")
        add_to_config "config.active_record.schema_format = :#{schema_format}"
        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate", "db:schema:dump"

          if schema_format == "ruby"
            schema_dump = File.read("db/schema.rb")
            schema_dump_animals = File.read("db/animals_schema.rb")
            assert_match(/create_table "books"/, schema_dump)
            assert_match(/create_table "dogs"/, schema_dump_animals)
          else
            schema_dump = File.read("db/structure.sql")
            schema_dump_animals = File.read("db/animals_structure.sql")
            assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"books"/, schema_dump)
            assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"dogs"/, schema_dump_animals)
          end

          rails "db:schema:load"

          ar_tables = lambda { rails("runner", "p ActiveRecord::Base.connection.tables").strip }
          animals_tables = lambda { rails("runner", "p AnimalsBase.connection.tables").strip }

          assert_equal '["schema_migrations", "ar_internal_metadata", "books"]', ar_tables[]
          assert_equal '["schema_migrations", "ar_internal_metadata", "dogs"]', animals_tables[]
        end
      end

      def db_migrate_and_schema_dump_and_load_one_database(database, schema_format)
        add_to_config "config.active_record.schema_format = :#{schema_format}"
        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate:#{database}", "db:schema:dump:#{database}"

          if schema_format == "ruby"
            if database == "primary"
              schema_dump = File.read("db/schema.rb")
              assert_not(File.exist?("db/animals_schema.rb"))
              assert_match(/create_table "books"/, schema_dump)
            else
              assert_not(File.exist?("db/schema.rb"))
              schema_dump_animals = File.read("db/animals_schema.rb")
              assert_match(/create_table "dogs"/, schema_dump_animals)
            end
          else
            if database == "primary"
              schema_dump = File.read("db/structure.sql")
              assert_not(File.exist?("db/animals_structure.sql"))
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"books"/, schema_dump)
            else
              assert_not(File.exist?("db/structure.sql"))
              schema_dump_animals = File.read("db/animals_structure.sql")
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"dogs"/, schema_dump_animals)
            end
          end

          rails "db:schema:load:#{database}"

          ar_tables = lambda { rails("runner", "p ActiveRecord::Base.connection.tables").strip }
          animals_tables = lambda { rails("runner", "p AnimalsBase.connection.tables").strip }

          if database == "primary"
            assert_equal '["schema_migrations", "ar_internal_metadata", "books"]', ar_tables[]
            assert_equal "[]", animals_tables[]
          else
            assert_equal "[]", ar_tables[]
            assert_equal '["schema_migrations", "ar_internal_metadata", "dogs"]', animals_tables[]
          end
        end
      end

      def db_migrate_name_dumps_the_schema(name, schema_format)
        add_to_config "config.active_record.schema_format = :#{schema_format}"
        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          generate_models_for_animals

          assert_not(File.exist?("db/schema.rb"))
          assert_not(File.exist?("db/animals_schema.rb"))
          assert_not(File.exist?("db/structure.sql"))
          assert_not(File.exist?("db/animals_structure.sql"))

          rails("db:migrate:#{name}")

          if schema_format == "ruby"
            if name == "primary"
              schema_dump = File.read("db/schema.rb")
              assert_not(File.exist?("db/animals_schema.rb"))
              assert_match(/create_table "books"/, schema_dump)
            else
              assert_not(File.exist?("db/schema.rb"))
              schema_dump_animals = File.read("db/animals_schema.rb")
              assert_match(/create_table "dogs"/, schema_dump_animals)
            end
          else
            if name == "primary"
              schema_dump = File.read("db/structure.sql")
              assert_not(File.exist?("db/animals_structure.sql"))
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"books"/, schema_dump)
            else
              assert_not(File.exist?("db/structure.sql"))
              schema_dump_animals = File.read("db/animals_structure.sql")
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"dogs"/, schema_dump_animals)
            end
          end
        end
      end

      def db_test_prepare_name(name, schema_format)
        add_to_config "config.active_record.schema_format = :#{schema_format}"
        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          generate_models_for_animals

          rails("db:migrate:#{name}", "db:schema:dump:#{name}")

          output = rails("db:test:prepare:#{name}", "--trace")
          assert_match(/Execute db:test:load_schema:#{name}/, output)

          ar_tables = lambda { rails("runner", "-e", "test", "p ActiveRecord::Base.connection.tables").strip }
          animals_tables = lambda { rails("runner",  "-e", "test", "p AnimalsBase.connection.tables").strip }

          if name == "primary"
            assert_equal ["schema_migrations", "ar_internal_metadata", "books"].sort, JSON.parse(ar_tables[]).sort
            assert_equal "[]", animals_tables[]
          else
            assert_equal "[]", ar_tables[]
            assert_equal ["schema_migrations", "ar_internal_metadata", "dogs"].sort, JSON.parse(animals_tables[]).sort
          end
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

      def db_setup
        Dir.chdir(app_path) do
          rails "db:migrate"
          rails "db:drop"
          output = rails("db:setup")
          assert_match(/Created database/, output)
          ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
            assert_match_namespace(db_config.name, output)
            assert File.exist?(db_config.database)
          end
        end
      end

      def db_setup_namespaced(namespace, expected_database)
        Dir.chdir(app_path) do
         rails "db:migrate"
         rails "db:drop:#{namespace}"
         output = rails("db:setup:#{namespace}")
         assert_match(/Created database/, output)
         assert_match_namespace(namespace, output)
         assert File.exist?(expected_database)
       end
      end

      def db_reset
        Dir.chdir(app_path) do
          rails "db:migrate"
          output = rails("db:reset")
          assert_match(/Dropped database/, output)
          assert_match(/Created database/, output)
          ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
            assert_match_namespace(db_config.name, output)
            assert File.exist?(db_config.database)
          end
        end
      end

      def db_reset_namespaced(namespace, expected_database)
        Dir.chdir(app_path) do
          rails "db:migrate"
          output = rails("db:reset:#{namespace}")
          assert_match(/Dropped database/, output)
          assert_match(/Created database/, output)
          assert_match_namespace(namespace, output)
          assert File.exist?(expected_database)
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

      def db_migrate_and_rollback(namespace = nil)
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails("db:migrate")

          if namespace
            rollback_output = rails("db:rollback:#{namespace}")
          else
            assert_raises RuntimeError, /You're using a multiple database application/ do
              rollback_output = rails("db:rollback")
            end
          end

          case namespace
          when "primary"
            assert_no_match(/OneMigration: reverted/, rollback_output)
            assert_match(/CreateBooks: reverted/, rollback_output)
          when nil
          else
            assert_no_match(/TwoMigration: reverted/, rollback_output)
            assert_match(/CreateDogs: reverted/, rollback_output)
          end
        end
      end

      def db_migrate_redo(namespace = nil)
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails("db:migrate")

          if namespace
            redo_output = rails("db:migrate:redo:#{namespace}")
          else
            assert_raises RuntimeError, /You're using a multiple database application/ do
              redo_output = rails("db:migrate:redo")
            end
          end

          case namespace
          when "primary"
            assert_no_match(/OneMigration/, redo_output)
            assert_match(/CreateBooks: reverted/, redo_output)
            assert_match(/CreateBooks: migrated/, redo_output)
          when nil
          else
            assert_no_match(/TwoMigration/, redo_output)
            assert_match(/CreateDogs: reverted/, redo_output)
            assert_match(/CreateDogs: migrated/, redo_output)
          end
        end
      end

      def db_prepare
        Dir.chdir(app_path) do
          generate_models_for_animals
          output = rails("db:prepare")

          ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
            if db_config.name == "primary"
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
          db_create_and_drop db_config.name, db_config.database
        end
      end

      test "db:create:namespace and db:drop:namespace works on specified databases" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_create_and_drop_namespace db_config.name, db_config.database
        end
      end

      test "db:migrate set back connection to its original state" do
        require "#{app_path}/config/environment"
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

      test "db:migrate:name sets the connection back to its original state" do
        require "#{app_path}/config/environment"
        Dir.chdir(app_path) do
          dummy_task = <<~RUBY
            task foo: :environment do
              Book.first
            end
          RUBY
          app_file("Rakefile", dummy_task, "a+")

          generate_models_for_animals

          rails("db:migrate:primary")

          assert_nothing_raised do
            rails("db:migrate:animals", "foo")
          end
        end
      end

      test "db:schema:load:name sets the connection back to its original state" do
        require "#{app_path}/config/environment"
        Dir.chdir(app_path) do
          dummy_task = <<~RUBY
            task foo: :environment do
              Book.first
            end
          RUBY
          app_file("Rakefile", dummy_task, "a+")

          generate_models_for_animals

          rails("db:migrate:primary")

          rails "db:migrate:animals", "db:schema:dump:animals"

          assert_nothing_raised do
            rails("db:schema:load:animals", "foo")
          end
        end
      end

      test "db:migrate respects timestamp ordering across databases" do
        require "#{app_path}/config/environment"
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/animals_migrate/04_four_migration.rb", <<-MIGRATION
        class FourMigration < ActiveRecord::Migration::Current
        end
        MIGRATION

        app_file "db/migrate/03_three_migration.rb", <<-MIGRATION
          class ThreeMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        Dir.chdir(app_path) do
          output = rails "db:migrate"
          entries = output.scan(/^== (\d+).+migrated/).map(&:first).map(&:to_i)
          assert_equal [1, 2, 3, 4], entries
        end
      end

      test "db:migrate respects timestamp ordering for primary database" do
        require "#{app_path}/config/environment"
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/migrate/03_three_migration.rb", <<-MIGRATION
          class ThreeMigration < ActiveRecord::Migration::Current
          end
        MIGRATION


        Dir.chdir(app_path) do
          rails "db:migrate:up:primary", "VERSION=01_one_migration.rb"
          rails "db:migrate:up:primary", "VERSION=03_three_migration.rb"
          output = rails "db:migrate"
          entries = output.scan(/^== (\d+).+migrated/).map(&:first).map(&:to_i)
          assert_equal [2], entries
        end
      end

      test "migrations in different directories can have the same timestamp" do
        require "#{app_path}/config/environment"
        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
            def change
	      create_table :posts do |t|
		t.string :title

		t.timestamps
	      end
            end
          end
        MIGRATION

        app_file "db/animals_migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
            def change
	      create_table :dogs do |t|
		t.string :name

		t.timestamps
	      end
            end
          end
        MIGRATION

        Dir.chdir(app_path) do
          output = rails "db:migrate"
          entries = output.scan(/^== (\d+).+migrated/).map(&:first).map(&:to_i)

          assert_match(/dogs/, output)
          assert_match(/posts/, output)
          assert_equal [1, 1], entries
        end
      end

      test "db:migrate and db:schema:dump and db:schema:load works on all databases" do
        db_migrate_and_schema_dump_and_load
      end

      test "db:migrate and db:schema:dump and db:schema:load works on all databases with sql option" do
        db_migrate_and_schema_dump_and_load "sql"
      end

      test "db:migrate:name dumps the schema for the primary database" do
        db_migrate_name_dumps_the_schema("primary", "ruby")
      end

      test "db:migrate:name dumps the schema for the animals database" do
        db_migrate_name_dumps_the_schema("animals", "ruby")
      end

      test "db:migrate:name dumps the structure for the primary database" do
        db_migrate_name_dumps_the_schema("primary", "sql")
      end

      test "db:migrate:name dumps the structure for the animals database" do
        db_migrate_name_dumps_the_schema("animals", "sql")
      end

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the primary database with a ruby schema" do
        db_migrate_and_schema_dump_and_load_one_database("primary", "ruby")
      end

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the animals database with a ruby schema" do
        db_migrate_and_schema_dump_and_load_one_database("animals", "ruby")
      end

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the primary database with a sql schema" do
        db_migrate_and_schema_dump_and_load_one_database("primary", "sql")
      end

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the animals database with a sql schema" do
        db_migrate_and_schema_dump_and_load_one_database("animals", "sql")
      end

      test "db:test:prepare:name works for the primary database with a ruby schema" do
        db_test_prepare_name("primary", "ruby")
      end

      test "db:test:prepare:name works for the animals database with a ruby schema" do
        db_test_prepare_name("animals", "ruby")
      end

      test "db:test:prepare:name works for the primary database with a sql schema" do
        db_test_prepare_name("primary", "sql")
      end

      test "db:test:prepare:name works for the animals database with a sql schema" do
        db_test_prepare_name("animals", "sql")
      end

      test "db:migrate:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_namespaced db_config.name
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

      test "db:migrate:redo raises in a multi-db application" do
        require "#{app_path}/config/environment"
        db_migrate_redo
      end

      test "db:migrate:redo:namespace works" do
        require "#{app_path}/config/environment"

        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        db_migrate_redo "primary"
        db_migrate_redo "animals"
      end

      test "db:rollback raises on a multi-db application" do
        require "#{app_path}/config/environment"

        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        db_migrate_and_rollback
      end

      test "db:rollback:namespace works" do
        require "#{app_path}/config/environment"

        app_file "db/migrate/01_one_migration.rb", <<-MIGRATION
          class OneMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        app_file "db/animals_migrate/02_two_migration.rb", <<-MIGRATION
          class TwoMigration < ActiveRecord::Migration::Current
          end
        MIGRATION

        db_migrate_and_rollback "primary"
        db_migrate_and_rollback "animals"
      end

      test "db:migrate:status works on all databases" do
        require "#{app_path}/config/environment"
        db_migrate_and_migrate_status
      end

      test "db:migrate:status:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_namespaced db_config.name
          db_migrate_status_namespaced db_config.name
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

      test "db:setup works on all databases" do
        require "#{app_path}/config/environment"
        db_setup
      end

      test "db:setup:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_setup_namespaced db_config.name, db_config.database
        end
      end

      test "db:reset works on all databases" do
        require "#{app_path}/config/environment"
        db_reset
      end

      test "db:reset:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_reset_namespaced db_config.name, db_config.database
        end
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

      test "db:prepare runs seeds once" do
        require "#{app_path}/config/environment"
        Dir.chdir(app_path) do
          use_postgresql(multi_db: true)

          rails "db:drop"
          generate_models_for_animals
          rails "generate", "model", "recipe", "title:string"

          app_file "db/seeds.rb", <<-RUBY
            Dog.create!
          RUBY

          rails("db:prepare")

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

        db_migrate_and_schema_dump_and_load

        app_file "db/seeds.rb", <<-RUBY
          print Book.connection.pool.db_config.database
        RUBY

        output = rails("db:seed")
        assert_equal output, "db/development.sqlite3"
      ensure
        ENV["RAILS_ENV"] = @old_rails_env
        ENV["RACK_ENV"] = @old_rack_env
      end

      test "db:create and db:drop don't raise errors when loading YAML with multiline ERB" do
        app_file "config/database.yml", <<-YAML
          development:
            primary:
              database: <%=
                Rails.application.config.database
              %>
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY

        db_create_and_drop_namespace("primary", "db/development.sqlite3")
      end

      test "db:create and db:drop don't raise errors when loading YAML containing conditional statements in ERB" do
        app_file "config/database.yml", <<-YAML
          development:
            primary:
            <% if Rails.application.config.database %>
              database: <%= Rails.application.config.database %>
            <% else %>
              database: db/default.sqlite3
            <% end %>
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3

        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY

        db_create_and_drop_namespace("primary", "db/development.sqlite3")
      end

      test "schema generation when dump_schema_after_migration is true schema_dump is false" do
        app_file "config/database.yml", <<~EOS
          development:
            primary:
              adapter: sqlite3
              database: dev_db
              schema_dump: false
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
              schema_dump: false
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          assert_not File.exist?("db/schema.rb"), "should not dump schema when configured not to"
          assert_not File.exist?("db/secondary_schema.rb"), "should not dump schema when configured not to"
        end
      end

      test "schema generation when dump_schema_after_migration is false and schema_dump is true" do
        add_to_config("config.active_record.dump_schema_after_migration = false")

        app_file "config/database.yml", <<~EOS
          development:
            primary:
              adapter: sqlite3
              database: dev_db
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          assert_not File.exist?("db/schema.rb"), "should not dump schema when configured not to"
          assert_not File.exist?("db/secondary_schema.rb"), "should not dump schema when configured not to"
        end
      end

      test "schema generation with schema dump only for primary" do
        app_file "config/database.yml", <<~EOS
          development:
            primary:
              adapter: sqlite3
              database: primary_dev_db
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
              schema_dump: false
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate:primary", "db:migrate:secondary"

          assert File.exist?("db/schema.rb"), "should not dump schema when configured not to"
          assert_not File.exist?("db/secondary_schema.rb"), "should not dump schema when configured not to"
        end
      end

      test "schema generation with schema dump only for secondary" do
        app_file "config/database.yml", <<~EOS
          development:
            primary:
              adapter: sqlite3
              database: primary_dev_db
              schema_dump: false
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate:primary", "db:migrate:secondary"

          assert_not File.exist?("db/schema.rb"), "should not dump schema when configured not to"
          assert File.exist?("db/secondary_schema.rb"), "should dump schema when configured to"
        end
      end

      test "schema generation when dump_schema_after_migration and schema_dump are true" do
        app_file "config/database.yml", <<~EOS
          development:
            primary:
              adapter: sqlite3
              database: dev_db
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
        EOS

        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "db:migrate"

          assert File.exist?("db/schema.rb"), "should dump schema when configured to"
          assert File.exist?("db/secondary_schema.rb"), "should dump schema when configured to"
        end
      end

      test "db:test:prepare don't raise errors when schema_dump is false" do
        app_file "config/database.yml", <<~EOS
          development: &development
            primary:
              adapter: sqlite3
              database: dev_db
              schema_dump: false
            secondary:
              adapter: sqlite3
              database: secondary_dev_db
              schema_dump: false
          test:
            <<: *development
        EOS

        Dir.chdir(app_path) do
          output = rails("db:test:prepare", "--trace")
          assert_match(/Execute db:test:prepare/, output)
        end
      end

      test "db:create and db:drop don't raise errors when loading YAML containing multiple ERB statements on the same line" do
        app_file "config/database.yml", <<-YAML
          development:
            primary:
              database: <% if Rails.application.config.database %><%= Rails.application.config.database %><% else %>db/default.sqlite3<% end %>
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY

        db_create_and_drop_namespace("primary", "db/development.sqlite3")
      end

      test "db:create and db:drop don't raise errors when loading YAML with single-line ERB" do
        app_file "config/database.yml", <<-YAML
          development:
            primary:
              <%= Rails.application.config.database ? 'database: db/development.sqlite3' : 'database: db/development.sqlite3' %>
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY

        db_create_and_drop_namespace("primary", "db/development.sqlite3")
      end

      test "db:create and db:drop don't raise errors when loading YAML which contains a key's value as an ERB statement" do
        app_file "config/database.yml", <<-YAML
          development:
            primary:
              database: <%= Rails.application.config.database ? 'db/development.sqlite3' : 'db/development.sqlite3' %>
              custom_option: <%= ENV['CUSTOM_OPTION'] %>
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
        YAML

        app_file "config/environments/development.rb", <<-RUBY
          Rails.application.configure do
            config.database = "db/development.sqlite3"
          end
        RUBY

        db_create_and_drop_namespace("primary", "db/development.sqlite3")
      end

      test "when there is no primary config, the first is chosen as the default" do
        app_file "config/database.yml", <<-YAML
          development:
            default:
              database: db/default.sqlite3
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
              migrations_paths: db/animals_migrate
        YAML

        db_migrate_and_schema_dump_and_load
      end

      test "when database_tasks is false, then do not run the database tasks on that db" do
        require "#{app_path}/config/environment"
        app_file "config/database.yml", <<-YAML
          development:
            primary:
              database: db/default.sqlite3
              adapter: sqlite3
            animals:
              database: db/development_animals.sqlite3
              adapter: sqlite3
              database_tasks: false
              schema_dump: true ### database_tasks should override all sub-settings
        YAML

        Dir.chdir(app_path) do
          animals_db_exists = lambda { rails("runner", "puts !!(AnimalsBase.connection rescue false)").strip }

          generate_models_for_animals

          assert_equal "true", animals_db_exists.call

          assert_not File.exist?("db/animals_schema.yml")

          error = assert_raises do
            rails "db:migrate:animals" ### Task not defined
          end
          assert_includes error.message, "See the list of available tasks"

          rails "db:schema:dump"
          assert_not File.exist?("db/animals_schema.yml")

          rails "db:drop"
          assert_equal "true", animals_db_exists.call
        end
      end

      test "destructive tasks are protected" do
        add_to_config "config.active_record.protected_environments = ['development', 'test']"

        require "#{app_path}/config/environment"

        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate"

          destructive_tasks = ["db:drop:animals", "db:schema:load:animals", "db:test:purge:animals"]

          destructive_tasks.each do |task|
            error = assert_raises("#{task} did not raise ActiveRecord::ProtectedEnvironmentError") { rails task }
            assert_match(/ActiveRecord::ProtectedEnvironmentError/, error.message)
          end
        end
      end
    end
  end
end
