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

      def db_migrate_and_schema_dump_and_load_one_database(format, database)
        Dir.chdir(app_path) do
          generate_models_for_animals
          rails "db:migrate:#{database}", "db:#{format}:dump:#{database}"

          if format == "schema"
            if database == "primary"
              schema_dump = File.read("db/#{format}.rb")
              assert_not(File.exist?("db/animals_#{format}.rb"))
              assert_match(/create_table "books"/, schema_dump)
            else
              assert_not(File.exist?("db/#{format}.rb"))
              schema_dump_animals = File.read("db/animals_#{format}.rb")
              assert_match(/create_table "dogs"/, schema_dump_animals)
            end
          else
            if database == "primary"
              schema_dump = File.read("db/#{format}.sql")
              assert_not(File.exist?("db/animals_#{format}.sql"))
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"books"/, schema_dump)
            else
              assert_not(File.exist?("db/#{format}.sql"))
              schema_dump_animals = File.read("db/animals_#{format}.sql")
              assert_match(/CREATE TABLE (?:IF NOT EXISTS )?"dogs"/, schema_dump_animals)
            end
          end

          rails "db:#{format}:load:#{database}"

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

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the primary database" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load_one_database("schema", "primary")
      end

      test "db:migrate:name and db:schema:dump:name and db:schema:load:name works for the animals database" do
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load_one_database("schema", "animals")
      end

      ["dump", "load"].each do |command|
        test "db:structure:#{command}:NAME is deprecated" do
          app_file "config/database.yml", <<-YAML
            default: &default
              adapter: sqlite3
            development:
              primary:
                <<: *default
              animals:
                <<: *default
                database: db/animals_development.sqlite3
          YAML

          add_to_config("config.active_support.deprecation = :stderr")
          stderr_output = capture(:stderr) { rails("db:structure:#{command}:animals", stderr: true, allow_failure: true) }
          assert_match(/DEPRECATION WARNING: Using `bin\/rails db:structure:#{command}:animals` is deprecated and will be removed in Rails 7.0/, stderr_output)
        end
      end

      test "db:migrate:name and db:structure:dump:name and db:structure:load:name works for the primary database" do
        add_to_config "config.active_record.schema_format = :sql"
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load_one_database("structure", "primary")
      end

      test "db:migrate:name and db:structure:dump:name and db:structure:load:name works for the animals database" do
        add_to_config "config.active_record.schema_format = :sql"
        require "#{app_path}/config/environment"
        db_migrate_and_schema_dump_and_load_one_database("structure", "animals")
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

      test "a thing" do
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
    end
  end
end
