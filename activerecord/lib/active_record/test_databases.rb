# frozen_string_literal: true

require "active_support/testing/parallelization"

module ActiveRecord
  module TestDatabases # :nodoc:
    ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
      create_and_load_schema(i, spec_name: Rails.env)
    end

    ActiveSupport::Testing::Parallelization.run_cleanup_hook do |_|
      drop(spec_name: Rails.env)
    end

    def self.create_and_load_schema(i, spec_name:)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"

      connection_spec = ActiveRecord::Base.configurations[spec_name]

      connection_spec["database"] += "-#{i}"
      ActiveRecord::Tasks::DatabaseTasks.create(connection_spec)
      ActiveRecord::Tasks::DatabaseTasks.load_schema(connection_spec)
    ensure
      ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[Rails.env])
      ENV["VERBOSE"] = old
    end

    def self.drop(spec_name:)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"
      connection_spec = ActiveRecord::Base.configurations[spec_name]

      ActiveRecord::Tasks::DatabaseTasks.drop(connection_spec)
    ensure
      ENV["VERBOSE"] = old
    end
  end
end
