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

        ignore_tables = ActiveRecord.schema_ignored_tables
        if ignore_tables.any?
          ignore_tables = connection.data_sources.select { |table| ignore_tables.any? { |pattern| pattern === table } }
          args += ignore_tables.map { |table| "--ignore-table=#{db_config.database}.#{table}" }
        end

        args.concat([db_config.database.to_s])
        args.unshift(*extra_flags) if extra_flags

        run_cmd("mysqldump", *args)
      end

      def structure_load(filename, extra_flags)
        extra_flags, init_commands = partition_init_commands(Array(extra_flags))

        args = prepare_command_options
        args.concat(["--database", db_config.database.to_s])
        args.unshift(*extra_flags)
        args.unshift("--init-command", ["SET FOREIGN_KEY_CHECKS = 0", *init_commands].join("; "))

        run_cmd("mysql", *args, in: filename)
      end

      private
        # The mysql client keeps only the last --init-command it is given, so
        # one passed through structure_load_flags would replace the statement
        # that disables foreign key checks. Split those off so that they can be
        # folded into a single --init-command.
        def partition_init_commands(flags)
          remaining = []
          init_commands = []
          flags = flags.dup

          while (flag = flags.shift)
            if flag == "--init-command"
              init_commands << flags.shift
            elsif flag.start_with?("--init-command=")
              init_commands << flag.delete_prefix("--init-command=")
            else
              remaining << flag
            end
          end

          [remaining, init_commands]
        end

        def creation_options
          Hash.new.tap do |options|
            options[:charset]     = configuration_hash[:encoding]   if configuration_hash.include?(:encoding)
            options[:collation]   = configuration_hash[:collation]  if configuration_hash.include?(:collation)
          end
        end

        def prepare_command_options
          db_config.adapter_class.cli_args(configuration_hash)
        end
    end
  end
end
