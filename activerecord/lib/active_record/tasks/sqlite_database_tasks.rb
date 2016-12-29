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
        `sqlite3 #{flags} #{dbfile} .schema > #{filename}`
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
