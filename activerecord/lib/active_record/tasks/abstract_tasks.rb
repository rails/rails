# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class AbstractTasks # :nodoc:
      def self.using_database_configurations?
        true
      end

      def initialize(db_config)
        @db_config = db_config
        @configuration_hash = db_config.configuration_hash
      end

      def charset
        connection.encoding
      end

      def collation
        connection.collation
      end

      def check_current_protected_environment!(db_config, migration_class)
        with_temporary_pool(db_config, migration_class) do |pool|
          migration_context = pool.migration_context
          current = migration_context.current_environment
          stored  = migration_context.last_stored_environment

          if migration_context.protected_environment?
            raise ActiveRecord::ProtectedEnvironmentError.new(stored)
          end

          if stored && stored != current
            raise ActiveRecord::EnvironmentMismatchError.new(current: current, stored: stored)
          end
        rescue ActiveRecord::NoDatabaseError
        end
      end

      private
        attr_reader :db_config, :configuration_hash

        def connection
          ActiveRecord::Base.lease_connection
        end

        def establish_connection(config = db_config)
          ActiveRecord::Base.establish_connection(config)
        end

        def configuration_hash_without_database
          configuration_hash.merge(database: nil)
        end

        def run_cmd(cmd, *args, **opts)
          fail run_cmd_error(cmd, args) unless Kernel.system(cmd, *args, opts)
        end

        def run_cmd_error(cmd, args)
          msg = +"failed to execute:\n"
          msg << "#{cmd} #{args.join(' ')}\n\n"
          msg << "Please check the output above for any errors and make sure that `#{cmd}` is installed in your PATH and has proper permissions.\n\n"
          msg
        end

        def with_temporary_pool(db_config, migration_class, clobber: false)
          original_db_config = migration_class.connection_db_config
          pool = migration_class.connection_handler.establish_connection(db_config, clobber: clobber)

          yield pool
        ensure
          migration_class.connection_handler.establish_connection(original_db_config, clobber: clobber)
        end
    end
  end
end
