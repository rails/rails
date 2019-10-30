# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def self.using_database_configurations?
        true
      end

      def initialize(db_config, root = ActiveRecord::Tasks::DatabaseTasks.root)
        @db_config = db_config
        @root = root
      end

      def create
        raise DatabaseAlreadyExists if database_exists?

        establish_connection(db_config)
        connection
      end

      def drop
        FileUtils.rm(database_file)
      rescue Errno::ENOENT => error
        raise NoDatabaseError.new(error.message)
      end

      def purge
        drop
      rescue NoDatabaseError
      ensure
        create
      end

      def charset
        connection.encoding
      end

      def structure_dump(filename, extra_flags)
        args = []
        args.concat(Array(extra_flags)) if extra_flags
        args << db_config.database

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          condition = ignore_tables.map { |table| connection.quote(table) }.join(", ")
          args << "SELECT sql FROM sqlite_master WHERE tbl_name NOT IN (#{condition}) ORDER BY tbl_name, type DESC, name"
        else
          args << ".schema"
        end
        run_cmd("sqlite3", args, filename)
      end

      def structure_load(filename, extra_flags)
        flags = extra_flags.join(" ") if extra_flags
        `sqlite3 #{flags} #{db_config.database} < "#{filename}"`
      end

      def database_exists?
        ActiveRecord::ConnectionAdapters::SQLite3Adapter.database_exists?(database: database_file)
      end

      private
        attr_reader :db_config, :root

        def database_file
          database = db_config.database
          if database == ":memory:"
            database
          else
            require "pathname"
            path = Pathname.new database
            path.absolute? ? path.to_s : File.join(root, path)
          end
        end

        def run_cmd(cmd, args, out)
          fail run_cmd_error(cmd, args) unless Kernel.system(cmd, *args, out: out)
        end

        def run_cmd_error(cmd, args)
          msg = +"failed to execute:\n"
          msg << "#{cmd} #{args.join(' ')}\n\n"
          msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
          msg
        end
    end
  end
end
