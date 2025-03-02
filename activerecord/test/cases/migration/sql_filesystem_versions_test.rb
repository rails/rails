# frozen_string_literal: true

require "cases/helper"
require "active_record/migration/sql_filesystem_versions"

module ActiveRecord
  class Migration
    class SqlFilesystemVersionsTest < ActiveRecord::TestCase
      class MockDatabaseTasks
        attr_reader :structure_dump_calls, :structure_load_calls

        def initialize
          @structure_dump_calls = []
          @structure_load_calls = []
        end

        def structure_dump(db_config, filename)
          @structure_dump_calls << [db_config, filename]
        end

        def structure_load(db_config, filename)
          @structure_load_calls << [db_config, filename]
          @loaded_content = File.read(filename)
        end

        def db_dir
          "db/"
        end

        attr_reader :loaded_content
      end

      def setup
        @connection_pool = ActiveRecord::Base.connection_pool
        connection = ActiveRecord::Base.connection

        # TODO: what is the proper way of dealing with lack of current_database in sqlite adapter?
        database_config = connection.instance_variable_get(:@config)
        database = database_config[:database]

        @db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          "test",
          "primary",
          {
            "adapter" => connection.adapter_name.downcase,
            "database" => database,
            "schema_migrations_path" => Dir.mktmpdir("schema_migrations")
          }
        )

        @schema_migration = @connection_pool.schema_migration
        @schema_migration.create_table
        @schema_migration.create_version("20230101000001")
        @schema_migration.create_version("20230102000002")

        @structure_file = Tempfile.new(["structure", ".sql"])
        @database_tasks = MockDatabaseTasks.new
      end

      def teardown
        @schema_migration.delete_version("20230101000001")
        @schema_migration.delete_version("20230102000002")

        @structure_file.close
        @structure_file.unlink

        FileUtils.remove_entry @db_config.schema_migrations_path
      end

      def test_dump_creates_schema_structure_file
        migration_operation = SqlFilesystemVersions.new(@db_config, @connection_pool, @database_tasks)
        migration_operation.dump(@structure_file.path)

        assert_equal 1, @database_tasks.structure_dump_calls.length, "Dump should be called once"
        assert_equal @db_config, @database_tasks.structure_dump_calls.first[0], "Dump should be called with correct db_config"
        assert_equal @structure_file.path, @database_tasks.structure_dump_calls.first[1], "Dump should be called with correct filename"

        migrations_path = @db_config.schema_migrations_path
        assert Dir.exist?(migrations_path), "Migrations directory should exist"

        ["20230101000001", "20230102000002"].each do |version|
          file_path = File.join(migrations_path, version)
          assert File.exist?(file_path), "Migration file #{version} should exist"
          assert_equal 64, File.read(file_path).length, "Content of migration file #{version} should be a SHA-256 hash"
        end
      end

      def test_load_with_existing_migrations
        migration_operation = SqlFilesystemVersions.new(@db_config, @connection_pool, @database_tasks)
        migrations_path = @db_config.schema_migrations_path
        FileUtils.mkdir_p(migrations_path)

        ["20230101000001", "20230102000002"].each do |version|
          File.open(File.join(migrations_path, version), "w") do |f|
            f.print Digest::SHA256.hexdigest(version)
          end
        end

        File.open(@structure_file.path, "w") do |f|
          f.puts "-- Structure dump content with migrations"
        end

        migration_operation.load(@structure_file.path)

        assert_equal 1, @database_tasks.structure_load_calls.length, "Load should be called once"
        assert_equal @db_config, @database_tasks.structure_load_calls.first[0], "Load should be called with correct db_config"

        temp_file_path = @database_tasks.structure_load_calls.first[1]
        assert_not_equal @structure_file.path, temp_file_path, "Load should be called with a temporary file"

        loaded_content = @database_tasks.loaded_content
        assert_match(/-- Structure dump content with migrations/, loaded_content)
        assert_match(/INSERT INTO.*schema_migrations.*20230102000002.*20230101000001/m, loaded_content)
      end

      def test_load_without_migrations
        migration_operation = SqlFilesystemVersions.new(@db_config, @connection_pool, @database_tasks)

        File.open(@structure_file.path, "w") do |f|
          f.puts "-- Structure dump content, no migrations"
        end

        migration_operation.load(@structure_file.path)

        assert_equal 1, @database_tasks.structure_load_calls.length, "Load should be called once"
        assert_equal @db_config, @database_tasks.structure_load_calls.first[0], "Load should be called with correct db_config"
        assert_equal @structure_file.path, @database_tasks.structure_load_calls.first[1], "Load should be called with correct filename"

        loaded_content = @database_tasks.loaded_content
        assert_match(/-- Structure dump content, no migrations/, loaded_content)
        assert_no_match(/INSERT INTO.*schema_migrations/, loaded_content)
      end
    end
  end
end
