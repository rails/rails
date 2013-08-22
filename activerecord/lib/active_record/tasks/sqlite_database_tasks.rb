module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration, root = Rails.root)
        @configuration, @root = configuration, root
      end

      def create
        raise DatabaseAlreadyExists if File.exist?(configuration['database'])

        establish_connection configuration
        connection
      end

      def drop
        file = dbfile
        FileUtils.rm(file) if File.exist?(file)
      end
      alias :purge :drop

      def charset
        connection.encoding
      end

      def structure_dump(filename)
        `sqlite3 #{dbfile} .schema > "#{filename}"`
      end

      def structure_load(filename)
        `sqlite3 #{dbfile} < "#{filename}"`
      end

      private

      def dbfile
        require 'pathname'
        path = Pathname.new configuration['database']
        path.absolute? ? path.to_s : File.join(root, path)
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
