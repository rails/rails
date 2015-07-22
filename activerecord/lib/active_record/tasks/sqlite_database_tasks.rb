module ActiveRecord
  module Tasks # :nodoc:
    class SQLiteDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration, root = ActiveRecord::Tasks::DatabaseTasks.root)
        @configuration, @root = configuration, root
      end

      def create
        raise DatabaseAlreadyExists if File.exist?(configuration['database'])

        establish_connection configuration
        connection
      end

      def drop
        require 'pathname'
        path = Pathname.new configuration['database']
        file = path.absolute? ? path.to_s : File.join(root, path)

        FileUtils.rm(file) if File.exist?(file)
      end

      def purge
        drop
        create
      end

      def charset
        connection.encoding
      end

      def structure_dump(filename)
        dbfile = configuration['database']
        command = "sqlite3 #{dbfile} > \"#{filename}\""
        unless Kernel.system(command)
          $stderr.puts "Could not dump the database structure. "\
                       "Make sure `sqlite3` is in your PATH and check the command output for warnings."
        end
      end

      def structure_load(filename)
        dbfile = configuration['database']
        command = "sqlite3 #{dbfile} < \"#{filename}\""
        unless Kernel.system(command)
          $stderr.puts "Could not load the database structure. "\
                       "Make sure `sqlite3` is in your PATH and check the command output for warnings."
        end
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
