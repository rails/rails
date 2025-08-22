# frozen_string_literal: true

require "tempfile"

module ActiveRecord
  module Tasks # :nodoc:
    class PostgreSQLDatabaseTasks # :nodoc:
      DEFAULT_ENCODING = ENV["CHARSET"] || "utf8"
      ON_ERROR_STOP_1 = "ON_ERROR_STOP=1"
      SQL_COMMENT_BEGIN = "--"

      def self.using_database_configurations?
        true
      end

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def create(connection_already_established = false)
        establish_connection(public_schema_config) unless connection_already_established
        connection.create_database(db_config.database, configuration_hash.merge(encoding: encoding))
        establish_connection
      end

      def drop
        establish_connection(public_schema_config)
        connection.drop_database(db_config.database)
      end

      def charset
        connection.encoding
      end

      def collation
        connection.collation
      end

      def purge
        ActiveRecord::Base.connection_handler.clear_active_connections!(:all)
        drop
        create true
      end

      def structure_dump(filename, extra_flags)
        search_path = \
          case ActiveRecord.dump_schemas
          when :schema_search_path
            configuration_hash[:schema_search_path]
          when :all
            nil
          when String
            ActiveRecord.dump_schemas
          end

        args = ["--schema-only", "--no-privileges", "--no-owner"]
        args.concat(["--file", filename])

        args.concat(Array(extra_flags)) if extra_flags

        unless search_path.blank?
          args += search_path.split(",").map do |part|
            "--schema=#{part.strip}"
          end
        end

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          ignore_tables = connection.data_sources.select { |table| ignore_tables.any? { |pattern| pattern === table } }
          args += ignore_tables.flat_map { |table| ["-T", table] }
        end

        args << db_config.database
        run_cmd("pg_dump", args, "dumping")
        remove_sql_header_comments(filename)
        File.open(filename, "a") { |f| f << "SET search_path TO #{connection.schema_search_path};\n\n" }
      end

      def structure_load(filename, extra_flags)
        args = ["--set", ON_ERROR_STOP_1, "--quiet", "--no-psqlrc", "--output", File::NULL]
        args.concat(Array(extra_flags)) if extra_flags
        args.concat(["--file", filename])
        args << db_config.database
        run_cmd("psql", args, "loading")
      end

      private
        attr_reader :db_config, :configuration_hash

        def connection
          ActiveRecord::Base.lease_connection
        end

        def establish_connection(config = db_config)
          ActiveRecord::Base.establish_connection(config)
        end

        def encoding
          configuration_hash[:encoding] || DEFAULT_ENCODING
        end

        def public_schema_config
          configuration_hash.merge(database: "postgres", schema_search_path: "public")
        end

        def psql_env
          {}.tap do |env|
            env["PGHOST"]         = db_config.host                        if db_config.host
            env["PGPORT"]         = configuration_hash[:port].to_s        if configuration_hash[:port]
            env["PGPASSWORD"]     = configuration_hash[:password].to_s    if configuration_hash[:password]
            env["PGUSER"]         = configuration_hash[:username].to_s    if configuration_hash[:username]
            env["PGSSLMODE"]      = configuration_hash[:sslmode].to_s     if configuration_hash[:sslmode]
            env["PGSSLCERT"]      = configuration_hash[:sslcert].to_s     if configuration_hash[:sslcert]
            env["PGSSLKEY"]       = configuration_hash[:sslkey].to_s      if configuration_hash[:sslkey]
            env["PGSSLROOTCERT"]  = configuration_hash[:sslrootcert].to_s if configuration_hash[:sslrootcert]
          end
        end

        def run_cmd(cmd, args, action)
          fail run_cmd_error(cmd, args, action) unless Kernel.system(psql_env, cmd, *args)
        end

        def run_cmd_error(cmd, args, action)
          msg = +"failed to execute:\n"
          msg << "#{cmd} #{args.join(' ')}\n\n"
          msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
          msg
        end

        def remove_sql_header_comments(filename)
          removing_comments = true
          tempfile = Tempfile.open("uncommented_structure.sql")
          begin
            File.foreach(filename) do |line|
              next if line.start_with?("\\restrict ")

              if line.start_with?("\\unrestrict ")
                removing_comments = true
                next
              end

              unless removing_comments && (line.start_with?(SQL_COMMENT_BEGIN) || line.blank?)
                tempfile << line
                removing_comments = false
              end
            end
          ensure
            tempfile.close
          end
          FileUtils.cp(tempfile.path, filename)
        end
    end
  end
end
