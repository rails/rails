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
        dbfile = configuration["database"]
        flags = extra_flags.join(" ") if extra_flags

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          tables = `sqlite3 #{dbfile} .tables`.split - ignore_tables
          condition = tables.map { |table| "tbl_name = '#{table}'" }.join(" OR ")
          statement = "SELECT sql FROM sqlite_master WHERE #{condition} ORDER BY tbl_name, type DESC, name"
          `sqlite3 #{flags} #{dbfile} "#{statement}" > #{filename}`
        else
          `sqlite3 #{flags} #{dbfile} .schema > #{filename}`
        end
      end

      def structure_load(filename, extra_flags)
        dbfile = configuration["database"]
        flags = extra_flags.join(" ") if extra_flags
        `sqlite3 #{flags} #{dbfile} < "#{filename}"`
      end

      private

        def configuration
          @configuration
        end

        def root
          @root
        end
    end
  end
end
