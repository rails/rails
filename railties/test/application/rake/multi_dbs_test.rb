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

      def db_migrate_and_schema_dump_and_load(namespace, expected_database, format)
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "generate", "model", "dog", "name:string"
          write_models_for_animals
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

      def db_migrate_namespaced(namespace, expected_database)
        Dir.chdir(app_path) do
          rails "generate", "model", "book", "title:string"
          rails "generate", "model", "dog", "name:string"
          write_models_for_animals
          output = rails("db:migrate:#{namespace}")
          if namespace == "primary"
            assert_match(/CreateBooks: migrated/, output)
          else
            assert_match(/CreateDogs: migrated/, output)
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
          file.write(<<-EOS
class AnimalsBase < ActiveRecord::Base
  self.abstract_class = true

  establish_connection :animals
end
EOS
)
        end
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

      test "db:migrate and db:schema:dump and db:schema:load works on all databases" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_and_schema_dump_and_load db_config.spec_name, db_config.config["database"], "schema"
        end
      end

      test "db:migrate and db:structure:dump and db:structure:load works on all databases" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_and_schema_dump_and_load db_config.spec_name, db_config.config["database"], "structure"
        end
      end

      test "db:migrate:namespace works" do
        require "#{app_path}/config/environment"
        ActiveRecord::Base.configurations.configs_for(env_name: Rails.env).each do |db_config|
          db_migrate_namespaced db_config.spec_name, db_config.config["database"]
        end
      end
    end
  end
end
