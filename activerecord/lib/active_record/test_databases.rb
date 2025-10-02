# frozen_string_literal: true

require "active_support/testing/parallelization"

module ActiveRecord
  module TestDatabases # :nodoc:
    ActiveSupport::Testing::Parallelization.before_fork_hook do
      if ActiveSupport.parallelize_test_databases
        ActiveRecord::Base.connection_handler.clear_all_connections!
      end
    end

    ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
      if ActiveSupport.parallelize_test_databases
        create_and_load_schema(i, env_name: ActiveRecord::ConnectionHandling::DEFAULT_ENV.call)
      end
    end

    def self.create_and_load_schema(i, env_name:)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"

      ActiveRecord::Base.configurations.configs_for(env_name: env_name, include_hidden: true).each do |db_config|
        db_config._database = "#{db_config.database}_#{i}"

        if db_config.database_tasks?
          ActiveRecord::Tasks::DatabaseTasks.reconstruct_from_schema(db_config, nil)
        end
      end
    ensure
      ActiveRecord::Base.establish_connection
      ENV["VERBOSE"] = old
    end
  end
end
