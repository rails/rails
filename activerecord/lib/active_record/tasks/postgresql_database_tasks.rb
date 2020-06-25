# frozen_string_literal: true

require "tempfile"

module ActiveRecord
  module Tasks # :nodoc:
    class PostgreSQLDatabaseTasks # :nodoc:
      DEFAULT_ENCODING = ENV.fetch("CHARSET", "utf8")
      ON_ERROR_STOP_1 = "ON_ERROR_STOP=1"
      SQL_COMMENT_BEGIN = "--"

      delegate :connection, :establish_connection, :clear_active_connections!,
        to: ActiveRecord::Base

      def self.using_database_configurations?
        true
      end

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def create(master_established = false)
        establish_master_connection unless master_established
        connection.create_database(db_config.database, configuration_hash.merge(encoding: encoding))
        establish_connection(db_config)
      end

      def drop
        establish_master_connection
        connection.drop_database(db_config.database)
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

      def structure_dump(filename, extra_flags)
        set_psql_env

        search_path = \
          case ActiveRecord::Base.dump_schemas
          when :schema_search_path
            configuration_hash[:schema_search_path]
          when :all
            nil
          when String
            ActiveRecord::Base.dump_schemas
          end

        args = ["--schema-only", "--no-privileges", "--no-owner", "--file", filename]
        args.concat(Array(extra_flags)) if extra_flags
        unless search_path.blank?
          args += search_path.split(",").map do |part|
            "--schema=#{part.strip}"
          end
        end

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          args += ignore_tables.flat_map { |table| ["-T", table] }
        end

        args << db_config.database
        run_cmd("pg_dump", args, "dumping")
        remove_sql_header_comments(filename)
        File.open(filename, "a") { |f| f << "SET search_path TO #{connection.schema_search_path};\n\n" }
      end

      def structure_load(filename, extra_flags)
        set_psql_env
        args = ["--set", ON_ERROR_STOP_1, "--quiet", "--no-psqlrc", "--file", filename]
        args.concat(Array(extra_flags)) if extra_flags
        args << db_config.database
        run_cmd("psql", args, "loading")
      end

      private
        attr_reader :db_config, :configuration_hash

        def encoding
          configuration_hash[:encoding] || DEFAULT_ENCODING
        end

        def establish_master_connection
          establish_connection configuration_hash.merge(
            database: "postgres",
            schema_search_path: "public"
          )
        end

        def set_psql_env
          ENV["PGHOST"]     = db_config.host                     if db_config.host
          ENV["PGPORT"]     = configuration_hash[:port].to_s     if configuration_hash[:port]
          ENV["PGPASSWORD"] = configuration_hash[:password].to_s if configuration_hash[:password]
          ENV["PGUSER"]     = configuration_hash[:username].to_s if configuration_hash[:username]
        end

        def run_cmd(cmd, args, action)
          fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
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
