# frozen_string_literal: true

require "digest"
require "tempfile"
require "fileutils"

module ActiveRecord
  class Migration
    # Handles schema dumping and loading operations for the :sql_filesystem_versions schema format.
    # This format keeps the schema in SQL format, but stores migration versions in separate files
    # to minimize conflicts when merging branches.
    class SqlFilesystemVersions
      MIGRATION_FILENAME_PATTERN = /\A\d+\z/

      def initialize(db_config, connection_pool, database_tasks)
        @db_config = db_config
        @connection_pool = connection_pool
        @database_tasks = database_tasks
      end

      # Dumps the schema structure to the structure.sql file and writes migration versions
      # to individual files in the migrations directory.
      def dump(structure_file)
        # First dump the structure without migrations
        database_tasks.structure_dump(db_config, structure_file)

        # If schema_migration table exists, store versions in individual files
        if connection_pool.schema_migration.table_exists?
          FileUtils.mkdir_p(migrations_path)

          # Clean existing migration files
          Dir.glob("*", base: migrations_path).each do |file|
            File.delete(File.join(migrations_path, file))
          end

          # Write each migration version to a separate file
          connection_pool.schema_migration.versions.each do |version|
            # Use the original version as filename for easy identification
            file_path = File.join(migrations_path, version)
            # Store the SHA-256 hash of the version in the file for consistent content length
            File.open(file_path, "w") do |f|
              f.print Digest::SHA256.hexdigest(version)
            end
          end
        end
      end

      # Loads the schema structure and migration versions atomically.
      def load(structure_file)
        versions = []

        # Collect valid migration versions from files
        if Dir.exist?(migrations_path)
          versions = Dir.glob("[0-9]*", base: migrations_path).select do |file|
            file =~ MIGRATION_FILENAME_PATTERN
          end.sort
        end

        # If we have versions to add, create a temporary file with combined structure and migrations
        if versions.any?
          with_temporary_structure_file(structure_file, versions) do |temp_file|
            temp_file.flush
            database_tasks.structure_load(db_config, temp_file.path)
          end
        else
          # Just load the original structure file if no versions exist
          database_tasks.structure_load(db_config, structure_file)
        end
      end

      private
        attr_reader :db_config, :connection_pool, :database_tasks

        def migrations_path
          db_config.schema_migrations_path(database_tasks.db_dir)
        end

        # Creates a temporary file with structure and migration versions for atomic loading
        def with_temporary_structure_file(structure_file, versions)
          temp_file = Tempfile.new(["temp_structure", ".sql"])
          begin
            # Copy existing structure
            File.open(structure_file, "r") do |input|
              temp_file.write(input.read)
            end

            # Append migration versions as an INSERT statement
            if versions.any?
              temp_file.puts
              connection_pool.with_connection do |conn|
                versions_formatter = ActiveRecord.schema_versions_formatter.new(conn)
                insert_statement = versions_formatter.format(versions)
                temp_file.puts insert_statement
                temp_file.flush
              end
            end

            yield temp_file
          ensure
            temp_file.close
            temp_file.unlink
          end
        end
    end
  end
end
