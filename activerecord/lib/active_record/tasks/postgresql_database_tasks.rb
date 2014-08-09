require 'shellwords'

module ActiveRecord
  module Tasks # :nodoc:
    class PostgreSQLDatabaseTasks # :nodoc:
      DEFAULT_ENCODING = ENV['CHARSET'] || 'utf8'

      delegate :connection, :establish_connection, :clear_active_connections!,
        to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create(master_established = false)
        establish_master_connection unless master_established
        connection.create_database configuration['database'],
          configuration.merge('encoding' => encoding)
        establish_connection configuration
      rescue ActiveRecord::StatementInvalid => error
        if /database .* already exists/ === error.message
          raise DatabaseAlreadyExists
        else
          raise
        end
      end

      def drop
        establish_master_connection
        connection.drop_database configuration['database']
      end

      def charset
        connection.encoding
      end

      def collation
        connection.collation
      end

      def purge
        clear_active_connections!
        drop
        create true
      end

      def structure_dump(filename)
        set_psql_env
        search_path = configuration['schema_search_path']
        unless search_path.blank?
          search_path = search_path.split(",").map{|search_path_part| "--schema=#{Shellwords.escape(search_path_part.strip)}" }.join(" ")
        end

        command = "pg_dump -i -s -x -O -f #{Shellwords.escape(filename)} #{search_path} #{Shellwords.escape(configuration['database'])}"
        raise 'Error dumping database' unless Kernel.system(command)

        File.open(filename, "a") { |f| f << "SET search_path TO #{connection.schema_search_path};\n\n" }
      end

      def structure_load(filename)
        set_psql_env
        Kernel.system("psql -q -f #{Shellwords.escape(filename)} #{configuration['database']}")
      end

      private

      def configuration
        @configuration
      end

      def encoding
        configuration['encoding'] || DEFAULT_ENCODING
      end

      def establish_master_connection
        establish_connection configuration.merge(
          'database'           => 'postgres',
          'schema_search_path' => 'public'
        )
      end

      def set_psql_env
        ENV['PGHOST']     = configuration['host']          if configuration['host']
        ENV['PGPORT']     = configuration['port'].to_s     if configuration['port']
        ENV['PGPASSWORD'] = configuration['password'].to_s if configuration['password']
        ENV['PGUSER']     = configuration['username'].to_s if configuration['username']
      end
    end
  end
end
