# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration, root = ActiveRecord::Tasks::DatabaseTasks.root)
        @configuration, @root = configuration, root
      end

      def create
        raise DatabaseAlreadyExists if File.exist?(configuration["database"])

        establish_connection configuration
        connection
      end

      def drop
        require "pathname"
        path = Pathname.new configuration["database"]
        file = path.absolute? ? path.to_s : File.join(root, path)

        FileUtils.rm(file)
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
        args << configuration["database"]

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
        dbfile = configuration["database"]
        flags = extra_flags.join(" ") if extra_flags
        `sqlite3 #{flags} #{dbfile} < "#{filename}"`
      end

      private

        attr_reader :configuration, :root

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
