# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class MySQLDatabaseTasks # :nodoc:
      ER_DB_CREATE_EXISTS = 1007

      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def self.using_database_configurations?
        true
      end

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def create
        establish_connection(configuration_hash_without_database)
        connection.create_database(db_config.database, creation_options)
        establish_connection(db_config)
      end

      def drop
        establish_connection(db_config)
        connection.drop_database(db_config.database)
      end

      def purge
        establish_connection(db_config)
        connection.recreate_database(db_config.database, creation_options)
      end

      def charset
        connection.charset
      end

      def collation
        connection.collation
      end

      def structure_dump(filename, extra_flags)
        args = prepare_command_options
        args.concat(["--result-file", "#{filename}"])
        args.concat(["--no-data"])
        args.concat(["--routines"])
        args.concat(["--skip-comments"])

        ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
        if ignore_tables.any?
          args += ignore_tables.map { |table| "--ignore-table=#{db_config.database}.#{table}" }
        end

        args.concat([db_config.database.to_s])
        args.unshift(*extra_flags) if extra_flags

        run_cmd("mysqldump", args, "dumping")
      end

      def structure_load(filename, extra_flags)
        args = prepare_command_options
        args.concat(["--execute", %{SET FOREIGN_KEY_CHECKS = 0; SOURCE #{filename}; SET FOREIGN_KEY_CHECKS = 1}])
        args.concat(["--database", db_config.database.to_s])
        args.unshift(*extra_flags) if extra_flags

        run_cmd("mysql", args, "loading")
      end

      private
        attr_reader :db_config, :configuration_hash

        def configuration_hash_without_database
          configuration_hash.merge(database: nil)
        end

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
            sslkey:    "--ssl-key"
          }.map { |opt, arg| "#{arg}=#{configuration_hash[opt]}" if configuration_hash[opt] }.compact

          args
        end

        def run_cmd(cmd, args, action)
          fail run_cmd_error(cmd, args, action) unless Kernel.system(cmd, *args)
        end

        def run_cmd_error(cmd, args, action)
          msg = +"failed to execute: `#{cmd}`\n"
          msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
          msg
        end
    end
  end
end
