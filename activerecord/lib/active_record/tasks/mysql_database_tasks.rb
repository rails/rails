# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class MySQLDatabaseTasks < AbstractTasks # :nodoc:
      def create
        establish_connection(configuration_hash_without_database)
        connection.create_database(db_config.database, creation_options)
        establish_connection
      end

      def drop
        establish_connection
        connection.drop_database(db_config.database)
      end

      def purge
        establish_connection(configuration_hash_without_database)
        connection.recreate_database(db_config.database, creation_options)
        establish_connection
      end

      def charset
        connection.charset
      end

      def structure_dump(filename, extra_flags)
        args = prepare_command_options
        args.concat(["--result-file", "#{filename}"])
        args.concat(["--no-data"])
        args.concat(["--routines"])
        args.concat(["--skip-comments"])

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          ignore_tables = connection.data_sources.select { |table| ignore_tables.any? { |pattern| pattern === table } }
          args += ignore_tables.map { |table| "--ignore-table=#{db_config.database}.#{table}" }
        end

        args.concat([db_config.database.to_s])
        args.unshift(*extra_flags) if extra_flags

        run_cmd("mysqldump", *args)
      end

      def structure_load(filename, extra_flags)
        args = prepare_command_options
        args.concat(["--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}])
        args.concat(["--database", db_config.database.to_s])
        args.unshift(*extra_flags) if extra_flags

        run_cmd("mysql", *args)
      end

      private
        def creation_options
          Hash.new.tap do |options|
            options[:charset]     = configuration_hash[:encoding]   if configuration_hash.include?(:encoding)
            options[:collation]   = configuration_hash[:collation]  if configuration_hash.include?(:collation)
          end
        end

        def prepare_command_options
          args = {
            host:      "--host",
            port:      "--port",
            socket:    "--socket",
            username:  "--user",
            password:  "--password",
            encoding:  "--default-character-set",
            sslca:     "--ssl-ca",
            sslcert:   "--ssl-cert",
            sslcapath: "--ssl-capath",
            sslcipher: "--ssl-cipher",
            sslkey:    "--ssl-key",
            ssl_mode:  "--ssl-mode"
          }.filter_map { |opt, arg| "#{arg}=#{configuration_hash[opt]}" if configuration_hash[opt] }

          args
        end
    end
  end
end
