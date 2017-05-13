module ActiveRecord
  # Superclass for all ActiveRecord migration errors.
  # Subclasses of this error class are:
  # - CommonMigrationError
  # - TaskMigrationError
  class MigrationError < ActiveRecordError#:nodoc:
    def initialize(message = nil)
      message = "\n\n#{message}\n\n" if message
      super
    end
  end

  #
  # Superclass for a subset of ActiveRecord::MigrationError errors
  #
  class CommonMigrationError < MigrationError #:nodoc:
  end

  # Exception that can be raised to stop migrations from being rolled back.
  # For example the following migration is not reversible.
  # Rolling back this migration will raise an ActiveRecord::IrreversibleMigration error.
  #
  #   class IrreversibleMigrationExample < ActiveRecord::Migration[5.0]
  #     def change
  #       create_table :distributors do |t|
  #         t.string :zipcode
  #       end
  #
  #       execute <<-SQL
  #         ALTER TABLE distributors
  #           ADD CONSTRAINT zipchk
  #             CHECK (char_length(zipcode) = 5) NO INHERIT;
  #       SQL
  #     end
  #   end
  #
  # There are two ways to mitigate this problem.
  #
  # 1. Define <tt>#up</tt> and <tt>#down</tt> methods instead of <tt>#change</tt>:
  #
  #  class ReversibleMigrationExample < ActiveRecord::Migration[5.0]
  #    def up
  #      create_table :distributors do |t|
  #        t.string :zipcode
  #      end
  #
  #      execute <<-SQL
  #        ALTER TABLE distributors
  #          ADD CONSTRAINT zipchk
  #            CHECK (char_length(zipcode) = 5) NO INHERIT;
  #      SQL
  #    end
  #
  #    def down
  #      execute <<-SQL
  #        ALTER TABLE distributors
  #          DROP CONSTRAINT zipchk
  #      SQL
  #
  #      drop_table :distributors
  #    end
  #  end
  #
  # 2. Use the #reversible method in <tt>#change</tt> method:
  #
  #   class ReversibleMigrationExample < ActiveRecord::Migration[5.0]
  #     def change
  #       create_table :distributors do |t|
  #         t.string :zipcode
  #       end
  #
  #       reversible do |dir|
  #         dir.up do
  #           execute <<-SQL
  #             ALTER TABLE distributors
  #               ADD CONSTRAINT zipchk
  #                 CHECK (char_length(zipcode) = 5) NO INHERIT;
  #           SQL
  #         end
  #
  #         dir.down do
  #           execute <<-SQL
  #             ALTER TABLE distributors
  #               DROP CONSTRAINT zipchk
  #           SQL
  #         end
  #       end
  #     end
  #   end
  class IrreversibleMigration < CommonMigrationError
  end

  # There is no test for this class
  class DuplicateMigrationError < CommonMigrationError
    def initialize(duplicate = nil)
      super("Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict.")
    end
  end

  class DuplicateMigrationVersionError < CommonMigrationError #:nodoc:
    def initialize(version = nil)
      if version
        super("Multiple migrations have the version number #{version}.")
      else
        super("Duplicate migration version error.")
      end
    end
  end

  class DuplicateMigrationNameError < CommonMigrationError #:nodoc:
    def initialize(name = nil)
      if name
        super("Multiple migrations have the name #{name}.")
      else
        super("Duplicate migration name.")
      end
    end
  end

  class UnknownMigrationVersionError < CommonMigrationError #:nodoc:
    def initialize(version = nil)
      if version
        super("No migration with version number #{version}.")
      else
        super("Unknown migration version.")
      end
    end
  end

  class IllegalMigrationNameError < CommonMigrationError #:nodoc:
    def initialize(name = nil)
      if name
        super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed).")
      else
        super("Illegal name for migration.")
      end
    end
  end

  class PendingMigrationError < CommonMigrationError #:nodoc:
    def initialize(message = nil)
      if !message && defined?(Rails.env)
        super("Migrations are pending. To resolve this issue, run:\n\n\tbin/rails db:migrate RAILS_ENV=#{::Rails.env}")
      elsif !message
        super("Migrations are pending. To resolve this issue, run:\n\n\tbin/rails db:migrate")
      else
        super
      end
    end
  end

  class ConcurrentMigrationError < CommonMigrationError #:nodoc:
    DEFAULT_MESSAGE = "Cannot run migrations because another migration process is currently running.".freeze

    def initialize(message = DEFAULT_MESSAGE)
      super
    end
  end

  class NoEnvironmentInSchemaError < CommonMigrationError #:nodoc:
    def initialize
      msg = "Environment data not found in the schema. To resolve this issue, run: \n\n\tbin/rails db:environment:set"
      if defined?(Rails.env)
        super("#{msg} RAILS_ENV=#{::Rails.env}")
      else
        super(msg)
      end
    end
  end

  #
  # Superclass for a subset of ActiveRecord::MigrationError errors
  #
  class TaskMigrationError < MigrationError
  end

  class ProtectedEnvironmentError < TaskMigrationError #:nodoc:
    def initialize(env = "production")
      msg = "You are attempting to run a destructive action against your '#{env}' database.\n"
      msg << "If you are sure you want to continue, run the same command with the environment variable:\n"
      msg << "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      super(msg)
    end
  end

  class EnvironmentMismatchError < TaskMigrationError
    def initialize(current: nil, stored: nil)
      msg =  "You are attempting to modify a database that was last run in `#{ stored }` environment.\n"
      msg << "You are running in `#{ current }` environment. "
      msg << "If you are sure you want to continue, first set the environment using:\n\n"
      msg << "\tbin/rails db:environment:set"
      if defined?(Rails.env)
        super("#{msg} RAILS_ENV=#{::Rails.env}\n\n")
      else
        super("#{msg}\n\n")
      end
    end
  end

  class DatabaseAlreadyExists < TaskMigrationError # :nodoc:
  end

  class DatabaseNotSupported < TaskMigrationError # :nodoc:
    def initialize(adapter = "undefined")
      super "Rake tasks not supported by '#{adapter}' adapter"
    end
  end

  class SeedLoaderNotSpecified < TaskMigrationError
    def initialize
      super "You tried to load seed data, but no seed loader is specified. Please specify seed " \
            "loader with ActiveRecord::Tasks::DatabaseTasks.seed_loader = your_seed_loader\n" \
            "Seed loader should respond to load_seed method"
    end
  end
end
