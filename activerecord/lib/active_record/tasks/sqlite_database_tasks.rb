# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks < AbstractTasks # :nodoc:
      def initialize(db_config, root = ActiveRecord::Tasks::DatabaseTasks.root)
        @db_config = db_config
        @root = root
      end

      def create
        raise DatabaseAlreadyExists if File.exist?(db_config.database)

        establish_connection
        connection
      end

      def drop
        db_path = db_config.database
        file = File.absolute_path?(db_path) ? db_path : File.join(root, db_path)
        FileUtils.rm(file)
        FileUtils.rm_f(["#{file}-shm", "#{file}-wal"])
      rescue Errno::ENOENT => error
        raise NoDatabaseError.new(error.message)
      end

      def purge
        connection.disconnect!
        drop
      rescue NoDatabaseError
      ensure
        create
        connection.reconnect!
      end

      def structure_dump(filename, extra_flags)
        args = []
        args.concat(Array(extra_flags)) if extra_flags
        args << db_config.database

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          ignore_tables = connection.data_sources.select { |table| ignore_tables.any? { |pattern| pattern === table } }
          condition = ignore_tables.map { |table| connection.quote(table) }.join(", ")
          args << "SELECT sql || ';' FROM sqlite_master WHERE tbl_name NOT IN (#{condition}) ORDER BY tbl_name, type DESC, name"
        else
          args << ".schema --nosys"
        end

        run_cmd("sqlite3", *args, out: filename)
      end

      def structure_load(filename, extra_flags)
        flags = extra_flags.join(" ") if extra_flags
        `sqlite3 #{flags} #{db_config.database} < "#{filename}"`
      end

      def check_current_protected_environment!(db_config, migration_class)
        super
      rescue ActiveRecord::StatementInvalid => e
        case e.cause
        when SQLite3::ReadOnlyException
        else
          raise e
        end
      end

      private
        attr_reader :root

        def establish_connection(config = db_config)
          ActiveRecord::Base.establish_connection(config)
          connection.connect!
        end
    end
  end
end
