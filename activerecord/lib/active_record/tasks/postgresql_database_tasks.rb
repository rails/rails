module ActiveRecord
  module Tasks # :nodoc:
    class PostgreSQLDatabaseTasks # :nodoc:
      DEFAULT_ENCODING = ENV["CHARSET"] || "utf8"
      ON_ERROR_STOP_1 = "ON_ERROR_STOP=1".freeze

      delegate :connection, :establish_connection, :clear_active_connections!,
        to: ActiveRecord::Base

      def initialize(configuration)
        @configuration = configuration
      end

      def create(master_established = false)
        establish_master_connection unless master_established
        connection.create_database configuration["database"],
          configuration.merge("encoding" => encoding)
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
        connection.drop_database configuration["database"]
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

        search_path = \
          case ActiveRecord::Base.dump_schemas
          when :schema_search_path
            configuration["schema_search_path"]
          when :all
            nil
          when String
            ActiveRecord::Base.dump_schemas
          end

        args = ["-s", "-x", "-O", "-f", filename]
        unless search_path.blank?
          args += search_path.split(",").map do |part|
            "--schema=#{part.strip}"
          end
        end
        args << configuration["database"]
        run_cmd("pg_dump", args, "dumping")
        File.open(filename, "a") { |f| f << "SET search_path TO #{connection.schema_search_path};\n\n" }
      end

      def structure_load(filename)
        set_psql_env
        args = [ "-v", ON_ERROR_STOP_1, "-q", "-f", filename, configuration["database"] ]
        run_cmd("psql", args, "loading" )
      end

      private

        def configuration
          @configuration
        end

        def encoding
          configuration["encoding"] || DEFAULT_ENCODING
        end

        def establish_master_connection
          establish_connection configuration.merge(
            "database"           => "postgres",
            "schema_search_path" => "public"
          )
        end

        def set_psql_env
          ENV["PGHOST"]     = configuration["host"]          if configuration["host"]
          ENV["PGPORT"]     = configuration["port"].to_s     if configuration["port"]
          ENV["PGPASSWORD"] = configuration["password"].to_s if configuration["password"]
          ENV["PGUSER"]     = configuration["username"].to_s if configuration["username"]
        end

        def run_cmd(cmd, args, action)
          fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
        end

        def run_cmd_error(cmd, args, action)
          msg = "failed to execute:\n"
          msg << "#{cmd} #{args.join(' ')}\n\n"
          msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
          msg
        end
    end
  end
end
