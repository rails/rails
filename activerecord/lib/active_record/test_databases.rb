require "active_support/testing/parallelization"

module ActiveRecord
  module TestDatabases
    ActiveSupport::Testing::Parallelization.after_fork_hook do |i|
      create_and_migrate(i)
    end

    ActiveSupport::Testing::Parallelization.run_cleanup_hook do |i|
      puts "stillcalling original?"
      drop(i)
    end

    def self.create_and_migrate(i)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"

      connection_spec = ActiveRecord::Base.configurations[Rails.env]

      connection_spec["database"] += "-#{i}"
      ActiveRecord::Tasks::DatabaseTasks.create(connection_spec)
      ActiveRecord::Base.establish_connection(connection_spec)
      if ActiveRecord::Migrator.needs_migration?
        ActiveRecord::Tasks::DatabaseTasks.migrate
      end
    ensure
      ENV["VERBOSE"] = old
    end

    def self.drop(i)
      old, ENV["VERBOSE"] = ENV["VERBOSE"], "false"
      connection_spec = ActiveRecord::Base.configurations[Rails.env]

      ActiveRecord::Tasks::DatabaseTasks.drop(connection_spec)
    ensure
      ENV["VERBOSE"] = old
    end
  end
end
