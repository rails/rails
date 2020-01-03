# frozen_string_literal: true

require "active_support/testing/parallelization"

module ActiveRecord
  module TestDatabases # :nodoc:
    ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
      create_and_load_schema(i, env_name: ActiveRecord::ConnectionHandling::DEFAULT_ENV.call)
    end

    def self.create_and_load_schema(i, env_name:)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"

      ActiveRecord::Base.configurations.configs_for(env_name: env_name).each do |db_config|
        database = "#{db_config.database}-#{i}"

        db_config_copy = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          env_name,
          db_config.spec_name,
          db_config.configuration_hash.merge(database: database)
        )

        # Reconstruct with the new configuration
        ActiveRecord::Tasks::DatabaseTasks.reconstruct_from_schema(db_config_copy, ActiveRecord::Base.schema_format, nil)

        # Replace the original configuration with our replacement
        ActiveRecord::Base.configurations.configurations.delete(db_config)
        ActiveRecord::Base.configurations.configurations.push(db_config_copy)
      end
    ensure
      ActiveRecord::Base.establish_connection(ActiveRecord::ConnectionHandling::DEFAULT_ENV.call.to_sym)
      ENV["VERBOSE"] = old
    end
  end
end
