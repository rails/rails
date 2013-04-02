module ActiveRecord
  module Tasks # :nodoc:
    class FirebirdDatabaseTasks # :nodoc:
      delegate :connection, :establish_connection, to: ActiveRecord::Base

      def initialize(configuration)
        ActiveSupport::Deprecation.warn "This database tasks were deprecated, because this tasks should be served by the 3rd party adapter."
        @configuration = configuration
      end

      def create
        $stderr.puts 'sorry, your database adapter is not supported yet, feel free to submit a patch'
      end

      def drop
        $stderr.puts 'sorry, your database adapter is not supported yet, feel free to submit a patch'
      end

      def purge
        establish_connection(:test)
        connection.recreate_database!
      end

      def charset
        $stderr.puts 'sorry, your database adapter is not supported yet, feel free to submit a patch'
      end

      def structure_dump(filename)
        set_firebird_env(configuration)
        db_string = firebird_db_string(configuration)
        Kernel.system "isql -a #{db_string} > #{filename}"
      end

      def structure_load(filename)
        set_firebird_env(configuration)
        db_string = firebird_db_string(configuration)
        Kernel.system "isql -i #{filename} #{db_string}"
      end

      private

      def set_firebird_env(config)
        ENV['ISC_USER']     = config['username'].to_s if config['username']
        ENV['ISC_PASSWORD'] = config['password'].to_s if config['password']
      end

      def firebird_db_string(config)
        FireRuby::Database.db_string_for(config.symbolize_keys)
      end

      def configuration
        @configuration
      end
    end
  end
end
