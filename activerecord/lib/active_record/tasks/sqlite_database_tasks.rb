module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration, root = ActiveRecord::Tasks::DatabaseTasks.root)
        require 'pathname'
        @configuration, @root = configuration, Pathname.new(root)
      end

      def create
        raise DatabaseAlreadyExists if File.exist?(configuration['database'])

        establish_connection configuration
        connection
      end

      def drop
        dbfile_path.delete if dbfile_path.exist?
      end
      alias :purge :drop

      def charset
        connection.encoding
      end

      def structure_dump(filename)
        `sqlite3 "#{dbfile_path}" .schema > "#{filename}"`
      end

      def structure_load(filename)
        `sqlite3 "#{dbfile_path}" < "#{filename}"`
      end

      private

        def dbfile_path
          @dbfile_path ||= begin
            path = Pathname.new configuration['database']
            path.absolute? ? path : root.join(path)
          end
        end

        def configuration
          @configuration
        end

        def root
          @root
        end
    end
  end
end
