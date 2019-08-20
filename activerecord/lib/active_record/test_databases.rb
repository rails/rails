# frozen_string_literal: true

require "active_support/testing/parallelization"

module ActiveRecord
  module TestDatabases # :nodoc:
    ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
      create_and_load_schema(i, env_name: Rails.env)
    end

    def self.create_and_load_schema(i, env_name:)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"

      ActiveRecord::Base.configurations.configs_for(env_name: env_name).each do |db_config|
        db_config.config["database"] += "-#{i}"
        ActiveRecord::Tasks::DatabaseTasks.reconstruct_from_schema(db_config.config, ActiveRecord::Base.schema_format, nil, env_name, db_config.spec_name)
      end
    ensure
      ActiveRecord::Base.establish_connection(Rails.env.to_sym)
      ENV["VERBOSE"] = old
    end
  end
end
