# frozen_string_literal: true

require "active_support/core_ext/array/access"
require "active_support/core_ext/enumerable"
require "active_support/core_ext/module/attribute_accessors"
require "active_support/actionable_error"
require "active_record/migration/pending_migration_connection"

module ActiveRecord
  class MigrationError < ActiveRecordError # :nodoc:
    def initialize(message = nil)
      message = "\n\n#{message}\n\n" if message
      super
    end
  end

  # Exception that can be raised to stop migrations from being rolled back.
  # For example the following migration is not reversible.
  # Rolling back this migration will raise an ActiveRecord::IrreversibleMigration error.
  #
  #   class IrreversibleMigrationExample < ActiveRecord::Migration[8.1]
  #     def change
  #       create_table :distributors do |t|
  #         t.string :zipcode
  #       end
  #
  #       execute <<~SQL
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
  #  class ReversibleMigrationExample < ActiveRecord::Migration[8.1]
  #    def up
  #      create_table :distributors do |t|
  #        t.string :zipcode
  #      end
  #
  #      execute <<~SQL
  #        ALTER TABLE distributors
  #          ADD CONSTRAINT zipchk
  #            CHECK (char_length(zipcode) = 5) NO INHERIT;
  #      SQL
  #    end
  #
  #    def down
  #      execute <<~SQL
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
  #   class ReversibleMigrationExample < ActiveRecord::Migration[8.1]
  #     def change
  #       create_table :distributors do |t|
  #         t.string :zipcode
  #       end
  #
  #       reversible do |dir|
  #         dir.up do
  #           execute <<~SQL
  #             ALTER TABLE distributors
  #               ADD CONSTRAINT zipchk
  #                 CHECK (char_length(zipcode) = 5) NO INHERIT;
  #           SQL
  #         end
  #
  #         dir.down do
  #           execute <<~SQL
  #             ALTER TABLE distributors
  #               DROP CONSTRAINT zipchk
  #           SQL
  #         end
  #       end
  #     end
  #   end
  class IrreversibleMigration < MigrationError
  end

  class DuplicateMigrationVersionError < MigrationError # :nodoc:
    def initialize(version = nil)
      if version
        super("Multiple migrations have the version number #{version}.")
      else
        super("Duplicate migration version error.")
      end
    end
  end

  class DuplicateMigrationNameError < MigrationError # :nodoc:
    def initialize(name = nil)
      if name
        super("Multiple migrations have the name #{name}.")
      else
        super("Duplicate migration name.")
      end
    end
  end

  class UnknownMigrationVersionError < MigrationError # :nodoc:
    def initialize(version = nil)
      if version
        super("No migration with version number #{version}.")
      else
        super("Unknown migration version.")
      end
    end
  end

  class IllegalMigrationNameError < MigrationError # :nodoc:
    def initialize(name = nil)
      if name
        super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed).")
      else
        super("Illegal name for migration.")
      end
    end
  end

  class InvalidMigrationTimestampError < MigrationError # :nodoc:
    def initialize(version = nil, name = nil)
      if version && name
        super(<<~MSG)
          Invalid timestamp #{version} for migration file: #{name}.
          Timestamp must be in form YYYYMMDDHHMMSS, and less than #{(Time.now.utc + 1.day).strftime("%Y%m%d%H%M%S")}.
        MSG
      else
        super(<<~MSG)
          Invalid timestamp for migration.
          Timestamp must be in form YYYYMMDDHHMMSS, and less than #{(Time.now.utc + 1.day).strftime("%Y%m%d%H%M%S")}.
        MSG
      end
    end
  end

  class PendingMigrationError < MigrationError # :nodoc:
    include ActiveSupport::ActionableError

    action "Run pending migrations" do
      ActiveRecord::Tasks::DatabaseTasks.migrate

      if ActiveRecord.dump_schema_after_migration
        connection = ActiveRecord::Tasks::DatabaseTasks.migration_connection
        ActiveRecord::Tasks::DatabaseTasks.dump_schema(connection.pool.db_config)
      end
    end

    def initialize(message = nil, pending_migrations: nil)
      if pending_migrations.nil?
        pending_migrations = connection_pool.migration_context.open.pending_migrations
      end

      super(message || detailed_migration_message(pending_migrations))
    end

    private
      def detailed_migration_message(pending_migrations)
        message = "Migrations are pending. To resolve this issue, run:\n\n        bin/rails db:migrate"
        message += " RAILS_ENV=#{::Rails.env}" if defined?(Rails.env) && !Rails.env.local?
        message += "\n\n"

        message += "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}\n\n"

        pending_migrations.each do |pending_migration|
          message += "#{pending_migration.filename}\n"
        end

        message
      end

      def connection_pool
        ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
      end
  end

  class ConcurrentMigrationError < MigrationError # :nodoc:
    DEFAULT_MESSAGE = "Cannot run migrations because another migration process is currently running."
    RELEASE_LOCK_FAILED_MESSAGE = "Failed to release advisory lock"

    def initialize(message = DEFAULT_MESSAGE)
      super
    end
  end

  class NoEnvironmentInSchemaError < MigrationError # :nodoc:
    def initialize
      msg = "Environment data not found in the schema. To resolve this issue, run: \n\n        bin/rails db:environment:set"
      if defined?(Rails.env)
        super("#{msg} RAILS_ENV=#{::Rails.env}")
      else
        super(msg)
      end
    end
  end

  class ProtectedEnvironmentError < ActiveRecordError # :nodoc:
    def initialize(env = "production")
      msg = +"You are attempting to run a destructive action against your '#{env}' database.\n"
      msg << "If you are sure you want to continue, run the same command with the environment variable:\n"
      msg << "DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
      super(msg)
    end
  end

  class EnvironmentMismatchError < ActiveRecordError
    def initialize(current: nil, stored: nil)
      msg = +"You are attempting to modify a database that was last run in `#{ stored }` environment.\n"
      msg << "You are running in `#{ current }` environment. "
      msg << "If you are sure you want to continue, first set the environment using:\n\n"
      msg << "        bin/rails db:environment:set"
      if defined?(Rails.env)
        super("#{msg} RAILS_ENV=#{::Rails.env}\n\n")
      else
        super("#{msg}\n\n")
      end
    end
  end

  class EnvironmentStorageError < ActiveRecordError # :nodoc:
    def initialize
      msg = +"You are attempting to store the environment in a database where metadata is disabled.\n"
      msg << "Check your database configuration to see if this is intended."
      super(msg)
    end
  end

  # = Active Record Migrations
  #
  # Migrations can manage the evolution of a schema used by several physical
  # databases. It's a solution to the common problem of adding a field to make
  # a new feature work in your local database, but being unsure of how to
  # push that change to other developers and to the production server. With
  # migrations, you can describe the transformations in self-contained classes
  # that can be checked into version control systems and executed against
  # another database that might be one, two, or five versions behind.
  #
  # Example of a simple migration:
  #
  #   class AddSsl < ActiveRecord::Migration[8.1]
  #     def up
  #       add_column :accounts, :ssl_enabled, :boolean, default: true
  #     end
  #
  #     def down
  #       remove_column :accounts, :ssl_enabled
  #     end
  #   end
  #
  # This migration will add a boolean flag to the accounts table and remove it
  # if you're backing out of the migration. It shows how all migrations have
  # two methods +up+ and +down+ that describes the transformations
  # required to implement or remove the migration. These methods can consist
  # of both the migration specific methods like +add_column+ and +remove_column+,
  # but may also contain regular Ruby code for generating data needed for the
  # transformations.
  #
  # Example of a more complex migration that also needs to initialize data:
  #
  #   class AddSystemSettings < ActiveRecord::Migration[8.1]
  #     def up
  #       create_table :system_settings do |t|
  #         t.string  :name
  #         t.string  :label
  #         t.text    :value
  #         t.string  :type
  #         t.integer :position
  #       end
  #
  #       SystemSetting.create  name:  'notice',
  #                             label: 'Use notice?',
  #                             value: 1
  #     end
  #
  #     def down
  #       drop_table :system_settings
  #     end
  #   end
  #
  # This migration first adds the +system_settings+ table, then creates the very
  # first row in it using the Active Record model that relies on the table. It
  # also uses the more advanced +create_table+ syntax where you can specify a
  # complete table schema in one block call.
  #
  # == Available transformations
  #
  # === Creation
  #
  # * <tt>create_join_table(table_1, table_2, options)</tt>: Creates a join
  #   table having its name as the lexical order of the first two
  #   arguments. See
  #   ActiveRecord::ConnectionAdapters::SchemaStatements#create_join_table for
  #   details.
  # * <tt>create_table(name, options)</tt>: Creates a table called +name+ and
  #   makes the table object available to a block that can then add columns to it,
  #   following the same format as +add_column+. See example above. The options hash
  #   is for fragments like "DEFAULT CHARSET=UTF-8" that are appended to the create
  #   table definition.
  # * <tt>add_column(table_name, column_name, type, options)</tt>: Adds a new column
  #   to the table called +table_name+
  #   named +column_name+ specified to be one of the following types:
  #   <tt>:string</tt>, <tt>:text</tt>, <tt>:integer</tt>, <tt>:float</tt>,
  #   <tt>:decimal</tt>, <tt>:datetime</tt>, <tt>:timestamp</tt>, <tt>:time</tt>,
  #   <tt>:date</tt>, <tt>:binary</tt>, <tt>:boolean</tt>. A default value can be
  #   specified by passing an +options+ hash like <tt>{ default: 11 }</tt>.
  #   Other options include <tt>:limit</tt> and <tt>:null</tt> (e.g.
  #   <tt>{ limit: 50, null: false }</tt>) -- see
  #   ActiveRecord::ConnectionAdapters::TableDefinition#column for details.
  # * <tt>add_foreign_key(from_table, to_table, options)</tt>: Adds a new
  #   foreign key. +from_table+ is the table with the key column, +to_table+ contains
  #   the referenced primary key.
  # * <tt>add_index(table_name, column_names, options)</tt>: Adds a new index
  #   with the name of the column. Other options include
  #   <tt>:name</tt>, <tt>:unique</tt> (e.g.
  #   <tt>{ name: 'users_name_index', unique: true }</tt>) and <tt>:order</tt>
  #   (e.g. <tt>{ order: { name: :desc } }</tt>).
  # * <tt>add_reference(:table_name, :reference_name)</tt>: Adds a new column
  #   +reference_name_id+ by default an integer. See
  #   ActiveRecord::ConnectionAdapters::SchemaStatements#add_reference for details.
  # * <tt>add_timestamps(table_name, options)</tt>: Adds timestamps (+created_at+
  #   and +updated_at+) columns to +table_name+.
  #
  # === Modification
  #
  # * <tt>change_column(table_name, column_name, type, options)</tt>:  Changes
  #   the column to a different type using the same parameters as add_column.
  # * <tt>change_column_default(table_name, column_name, default_or_changes)</tt>:
  #   Sets a default value for +column_name+ defined by +default_or_changes+ on
  #   +table_name+. Passing a hash containing <tt>:from</tt> and <tt>:to</tt>
  #   as +default_or_changes+ will make this change reversible in the migration.
  # * <tt>change_column_null(table_name, column_name, null, default = nil)</tt>:
  #   Sets or removes a <tt>NOT NULL</tt> constraint on +column_name+. The +null+ flag
  #   indicates whether the value can be +NULL+. See
  #   ActiveRecord::ConnectionAdapters::SchemaStatements#change_column_null for
  #   details.
  # * <tt>change_table(name, options)</tt>: Allows to make column alterations to
  #   the table called +name+. It makes the table object available to a block that
  #   can then add/remove columns, indexes, or foreign keys to it.
  # * <tt>rename_column(table_name, column_name, new_column_name)</tt>: Renames
  #   a column but keeps the type and content.
  # * <tt>rename_index(table_name, old_name, new_name)</tt>: Renames an index.
  # * <tt>rename_table(old_name, new_name)</tt>: Renames the table called +old_name+
  #   to +new_name+.
  #
  # === Deletion
  #
  # * <tt>drop_table(*names)</tt>: Drops the given tables.
  # * <tt>drop_join_table(table_1, table_2, options)</tt>: Drops the join table
  #   specified by the given arguments.
  # * <tt>remove_column(table_name, column_name, type, options)</tt>: Removes the column
  #   named +column_name+ from the table called +table_name+.
  # * <tt>remove_columns(table_name, *column_names)</tt>: Removes the given
  #   columns from the table definition.
  # * <tt>remove_foreign_key(from_table, to_table = nil, **options)</tt>: Removes the
  #   given foreign key from the table called +table_name+.
  # * <tt>remove_index(table_name, column: column_names)</tt>: Removes the index
  #   specified by +column_names+.
  # * <tt>remove_index(table_name, name: index_name)</tt>: Removes the index
  #   specified by +index_name+.
  # * <tt>remove_reference(table_name, ref_name, options)</tt>: Removes the
  #   reference(s) on +table_name+ specified by +ref_name+.
  # * <tt>remove_timestamps(table_name, options)</tt>: Removes the timestamp
  #   columns (+created_at+ and +updated_at+) from the table definition.
  #
  # == Irreversible transformations
  #
  # Some transformations are destructive in a manner that cannot be reversed.
  # Migrations of that kind should raise an ActiveRecord::IrreversibleMigration
  # exception in their +down+ method.
  #
  # == Running migrations from within \Rails
  #
  # The \Rails package has several tools to help create and apply migrations.
  #
  # To generate a new migration, you can use
  #
  #   $ bin/rails generate migration MyNewMigration
  #
  # where MyNewMigration is the name of your migration. The generator will
  # create an empty migration file <tt>timestamp_my_new_migration.rb</tt>
  # in the <tt>db/migrate/</tt> directory where <tt>timestamp</tt> is the
  # UTC formatted date and time that the migration was generated.
  #
  # There is a special syntactic shortcut to generate migrations that add fields to a table.
  #
  #   $ bin/rails generate migration add_fieldname_to_tablename fieldname:string
  #
  # This will generate the file <tt>timestamp_add_fieldname_to_tablename.rb</tt>, which will look like this:
  #   class AddFieldnameToTablename < ActiveRecord::Migration[8.1]
  #     def change
  #       add_column :tablenames, :fieldname, :string
  #     end
  #   end
  #
  # To run migrations against the currently configured database, use
  # <tt>bin/rails db:migrate</tt>. This will update the database by running all of the
  # pending migrations, creating the <tt>schema_migrations</tt> table
  # (see "About the schema_migrations table" section below) if missing. It will also
  # invoke the db:schema:dump command, which will update your db/schema.rb file
  # to match the structure of your database.
  #
  # To roll the database back to a previous migration version, use
  # <tt>bin/rails db:rollback VERSION=X</tt> where <tt>X</tt> is the version to which
  # you wish to downgrade. Alternatively, you can also use the STEP option if you
  # wish to rollback last few migrations. <tt>bin/rails db:rollback STEP=2</tt> will rollback
  # the latest two migrations.
  #
  # If any of the migrations throw an ActiveRecord::IrreversibleMigration exception,
  # that step will fail and you'll have some manual work to do.
  #
  # == More examples
  #
  # Not all migrations change the schema. Some just fix the data:
  #
  #   class RemoveEmptyTags < ActiveRecord::Migration[8.1]
  #     def up
  #       Tag.all.each { |tag| tag.destroy if tag.pages.empty? }
  #     end
  #
  #     def down
  #       # not much we can do to restore deleted data
  #       raise ActiveRecord::IrreversibleMigration, "Can't recover the deleted tags"
  #     end
  #   end
  #
  # Others remove columns when they migrate up instead of down:
  #
  #   class RemoveUnnecessaryItemAttributes < ActiveRecord::Migration[8.1]
  #     def up
  #       remove_column :items, :incomplete_items_count
  #       remove_column :items, :completed_items_count
  #     end
  #
  #     def down
  #       add_column :items, :incomplete_items_count
  #       add_column :items, :completed_items_count
  #     end
  #   end
  #
  # And sometimes you need to do something in SQL not abstracted directly by migrations:
  #
  #   class MakeJoinUnique < ActiveRecord::Migration[8.1]
  #     def up
  #       execute "ALTER TABLE `pages_linked_pages` ADD UNIQUE `page_id_linked_page_id` (`page_id`,`linked_page_id`)"
  #     end
  #
  #     def down
  #       execute "ALTER TABLE `pages_linked_pages` DROP INDEX `page_id_linked_page_id`"
  #     end
  #   end
  #
  # == Using a model after changing its table
  #
  # Sometimes you'll want to add a column in a migration and populate it
  # immediately after. In that case, you'll need to make a call to
  # <tt>Base#reset_column_information</tt> in order to ensure that the model has the
  # latest column data from after the new column was added. Example:
  #
  #   class AddPeopleSalary < ActiveRecord::Migration[8.1]
  #     def up
  #       add_column :people, :salary, :integer
  #       Person.reset_column_information
  #       Person.all.each do |p|
  #         p.update_attribute :salary, SalaryCalculator.compute(p)
  #       end
  #     end
  #   end
  #
  # == Controlling verbosity
  #
  # By default, migrations will describe the actions they are taking, writing
  # them to the console as they happen, along with benchmarks describing how
  # long each step took.
  #
  # You can quiet them down by setting <tt>ActiveRecord::Migration.verbose = false</tt>.
  #
  # You can also insert your own messages and benchmarks by using the +say_with_time+
  # method:
  #
  #   def up
  #     ...
  #     say_with_time "Updating salaries..." do
  #       Person.all.each do |p|
  #         p.update_attribute :salary, SalaryCalculator.compute(p)
  #       end
  #     end
  #     ...
  #   end
  #
  # The phrase "Updating salaries..." would then be printed, along with the
  # benchmark for the block when the block completes.
  #
  # == Timestamped Migrations
  #
  # By default, \Rails generates migrations that look like:
  #
  #    20080717013526_your_migration_name.rb
  #
  # The prefix is a generation timestamp (in UTC). Timestamps should not be
  # modified manually. To validate that migration timestamps adhere to the
  # format Active Record expects, you can use the following configuration option:
  #
  #    config.active_record.validate_migration_timestamps = true
  #
  # If you'd prefer to use numeric prefixes, you can turn timestamped migrations
  # off by setting:
  #
  #    config.active_record.timestamped_migrations = false
  #
  # In application.rb.
  #
  # == Reversible Migrations
  #
  # Reversible migrations are migrations that know how to go +down+ for you.
  # You simply supply the +up+ logic, and the Migration system figures out
  # how to execute the down commands for you.
  #
  # To define a reversible migration, define the +change+ method in your
  # migration like this:
  #
  #   class TenderloveMigration < ActiveRecord::Migration[8.1]
  #     def change
  #       create_table(:horses) do |t|
  #         t.column :content, :text
  #         t.column :remind_at, :datetime
  #       end
  #     end
  #   end
  #
  # This migration will create the horses table for you on the way up, and
  # automatically figure out how to drop the table on the way down.
  #
  # Some commands cannot be reversed. If you care to define how to move up
  # and down in these cases, you should define the +up+ and +down+ methods
  # as before.
  #
  # If a command cannot be reversed, an
  # ActiveRecord::IrreversibleMigration exception will be raised when
  # the migration is moving down.
  #
  # For a list of commands that are reversible, please see
  # +ActiveRecord::Migration::CommandRecorder+.
  #
  # == Transactional Migrations
  #
  # If the database adapter supports DDL transactions, all migrations will
  # automatically be wrapped in a transaction. There are queries that you
  # can't execute inside a transaction though, and for these situations
  # you can turn the automatic transactions off.
  #
  #   class ChangeEnum < ActiveRecord::Migration[8.1]
  #     disable_ddl_transaction!
  #
  #     def up
  #       execute "ALTER TYPE model_size ADD VALUE 'new_value'"
  #     end
  #   end
  #
  # Remember that you can still open your own transactions, even if you
  # are in a Migration with <tt>self.disable_ddl_transaction!</tt>.
  class Migration
    autoload :CommandRecorder, "active_record/migration/command_recorder"
    autoload :Compatibility, "active_record/migration/compatibility"
    autoload :DefaultSchemaVersionsFormatter, "active_record/migration/default_schema_versions_formatter"
    autoload :JoinTable, "active_record/migration/join_table"
    autoload :ExecutionStrategy, "active_record/migration/execution_strategy"
    autoload :DefaultStrategy, "active_record/migration/default_strategy"

    # This must be defined before the inherited hook, below
    class Current < Migration # :nodoc:
      def create_table(table_name, **options)
        if block_given?
          super { |t| yield compatible_table_definition(t) }
        else
          super
        end
      end

      def change_table(table_name, **options)
        if block_given?
          super { |t| yield compatible_table_definition(t) }
        else
          super
        end
      end

      def create_join_table(table_1, table_2, **options)
        if block_given?
          super { |t| yield compatible_table_definition(t) }
        else
          super
        end
      end

      def drop_table(*table_names, **options)
        if block_given?
          super { |t| yield compatible_table_definition(t) }
        else
          super
        end
      end

      def compatible_table_definition(t)
        t
      end
    end

    def self.inherited(subclass) # :nodoc:
      super
      if subclass.superclass == Migration
        major = ActiveRecord::VERSION::MAJOR
        minor = ActiveRecord::VERSION::MINOR
        raise StandardError, "Directly inheriting from ActiveRecord::Migration is not supported. " \
          "Please specify the Active Record release the migration was written for:\n" \
          "\n" \
          "  class #{subclass} < ActiveRecord::Migration[#{major}.#{minor}]"
      end
    end

    def self.[](version)
      Compatibility.find(version)
    end

    def self.current_version
      ActiveRecord::VERSION::STRING.to_f
    end

    MigrationFilenameRegexp = /\A([0-9]+)_([_a-z0-9]*)\.?([_a-z0-9]*)?\.rb\z/ # :nodoc:

    def self.valid_version_format?(version_string) # :nodoc:
      [
        MigrationFilenameRegexp,
        /\A\d(_?\d)*\z/ # integer with optional underscores
      ].any? { |pattern| pattern.match?(version_string) }
    end

    # This class is used to verify that all migrations have been run before
    # loading a web page if <tt>config.active_record.migration_error</tt> is set to +:page_load+.
    class CheckPending
      def initialize(app, file_watcher: ActiveSupport::FileUpdateChecker)
        @app = app
        @needs_check = true
        @mutex = Mutex.new
        @file_watcher = file_watcher
      end

      def call(env)
        @mutex.synchronize do
          @watcher ||= build_watcher do
            @needs_check = true
            ActiveRecord::Migration.check_pending_migrations
            @needs_check = false
          end

          if @needs_check
            @watcher.execute
          else
            @watcher.execute_if_updated
          end
        end

        @app.call(env)
      end

      private
        def build_watcher(&block)
          current_environment = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
          all_configs = ActiveRecord::Base.configurations.configs_for(env_name: current_environment)
          paths = all_configs.flat_map { |config| config.migrations_paths || Migrator.migrations_paths }.uniq
          @file_watcher.new([], paths.index_with(["rb"]), &block)
        end
    end

    class << self
      attr_accessor :delegate # :nodoc:
      attr_accessor :disable_ddl_transaction # :nodoc:

      def nearest_delegate # :nodoc:
        delegate || superclass.nearest_delegate
      end

      # Raises ActiveRecord::PendingMigrationError error if any migrations are pending
      # for all database configurations in an environment.
      def check_all_pending!
        pending_migrations = []

        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: env) do |pool|
          if pending = pool.migration_context.open.pending_migrations
            pending_migrations << pending
          end
        end

        migrations = pending_migrations.flatten

        if migrations.any?
          raise ActiveRecord::PendingMigrationError.new(pending_migrations: migrations)
        end
      end

      def load_schema_if_pending!
        if any_schema_needs_update?
          load_schema!
        end

        check_pending_migrations
      end

      def maintain_test_schema! # :nodoc:
        if ActiveRecord.maintain_test_schema
          suppress_messages { load_schema_if_pending! }
        end
      end

      def method_missing(name, ...) # :nodoc:
        nearest_delegate.send(name, ...)
      end

      def migrate(direction)
        new.migrate direction
      end

      # Disable the transaction wrapping this migration.
      # You can still create your own transactions even after calling #disable_ddl_transaction!
      #
      # For more details read the {"Transactional Migrations" section above}[rdoc-ref:Migration].
      def disable_ddl_transaction!
        @disable_ddl_transaction = true
      end

      def check_pending_migrations # :nodoc:
        migrations = pending_migrations

        if migrations.any?
          raise ActiveRecord::PendingMigrationError.new(pending_migrations: migrations)
        end
      end

      private
        def any_schema_needs_update?
          !db_configs_in_current_env.all? do |db_config|
            Tasks::DatabaseTasks.schema_up_to_date?(db_config, ActiveRecord.schema_format)
          end
        end

        def db_configs_in_current_env
          ActiveRecord::Base.configurations.configs_for(env_name: env)
        end

        def pending_migrations
          pending_migrations = []

          ActiveRecord::Base.configurations.configs_for(env_name: env).each do |db_config|
            ActiveRecord::PendingMigrationConnection.with_temporary_pool(db_config) do |pool|
              if pending = pool.migration_context.open.pending_migrations
                pending_migrations << pending
              end
            end
          end

          pending_migrations.flatten
        end

        def env
          ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
        end

        def load_schema!
          # Roundtrip to Rake to allow plugins to hook into database initialization.
          root = defined?(ENGINE_ROOT) ? ENGINE_ROOT : Rails.root

          FileUtils.cd(root) do
            Base.connection_handler.clear_all_connections!(:all)
            system("bin/rails db:test:prepare")
          end
        end
    end

    def disable_ddl_transaction # :nodoc:
      self.class.disable_ddl_transaction
    end

    ##
    # :singleton-method: verbose
    #
    # Specifies if migrations will write the actions they are taking to the console as they
    # happen, along with benchmarks describing how long each step took. Defaults to
    # true.
    cattr_accessor :verbose
    attr_accessor :name, :version

    def initialize(name = self.class.name, version = nil)
      @name       = name
      @version    = version
      @connection = nil
      @pool       = nil
    end

    def execution_strategy
      @execution_strategy ||= ActiveRecord.migration_strategy.new(self)
    end

    self.verbose = true
    # instantiate the delegate object after initialize is defined
    self.delegate = new

    # Reverses the migration commands for the given block and
    # the given migrations.
    #
    # The following migration will remove the table 'horses'
    # and create the table 'apples' on the way up, and the reverse
    # on the way down.
    #
    #   class FixTLMigration < ActiveRecord::Migration[8.1]
    #     def change
    #       revert do
    #         create_table(:horses) do |t|
    #           t.text :content
    #           t.datetime :remind_at
    #         end
    #       end
    #       create_table(:apples) do |t|
    #         t.string :variety
    #       end
    #     end
    #   end
    #
    # Or equivalently, if +TenderloveMigration+ is defined as in the
    # documentation for Migration:
    #
    #   require_relative "20121212123456_tenderlove_migration"
    #
    #   class FixupTLMigration < ActiveRecord::Migration[8.1]
    #     def change
    #       revert TenderloveMigration
    #
    #       create_table(:apples) do |t|
    #         t.string :variety
    #       end
    #     end
    #   end
    #
    # This command can be nested.
    def revert(*migration_classes, &block)
      run(*migration_classes.reverse, revert: true) unless migration_classes.empty?
      if block_given?
        if connection.respond_to? :revert
          connection.revert(&block)
        else
          recorder = command_recorder
          @connection = recorder
          suppress_messages do
            connection.revert(&block)
          end
          @connection = recorder.delegate
          recorder.replay(self)
        end
      end
    end

    def reverting?
      connection.respond_to?(:reverting) && connection.reverting
    end

    ReversibleBlockHelper = Struct.new(:reverting) do # :nodoc:
      def up
        yield unless reverting
      end

      def down
        yield if reverting
      end
    end

    # Used to specify an operation that can be run in one direction or another.
    # Call the methods +up+ and +down+ of the yielded object to run a block
    # only in one given direction.
    # The whole block will be called in the right order within the migration.
    #
    # In the following example, the looping on users will always be done
    # when the three columns 'first_name', 'last_name' and 'full_name' exist,
    # even when migrating down:
    #
    #    class SplitNameMigration < ActiveRecord::Migration[8.1]
    #      def change
    #        add_column :users, :first_name, :string
    #        add_column :users, :last_name, :string
    #
    #        reversible do |dir|
    #          User.reset_column_information
    #          User.all.each do |u|
    #            dir.up   { u.first_name, u.last_name = u.full_name.split(' ') }
    #            dir.down { u.full_name = "#{u.first_name} #{u.last_name}" }
    #            u.save
    #          end
    #        end
    #
    #        revert { add_column :users, :full_name, :string }
    #      end
    #    end
    def reversible
      helper = ReversibleBlockHelper.new(reverting?)
      execute_block { yield helper }
    end

    # Used to specify an operation that is only run when migrating up
    # (for example, populating a new column with its initial values).
    #
    # In the following example, the new column +published+ will be given
    # the value +true+ for all existing records.
    #
    #    class AddPublishedToPosts < ActiveRecord::Migration[8.1]
    #      def change
    #        add_column :posts, :published, :boolean, default: false
    #        up_only do
    #          execute "update posts set published = 'true'"
    #        end
    #      end
    #    end
    def up_only(&block)
      execute_block(&block) unless reverting?
    end

    # Runs the given migration classes.
    # Last argument can specify options:
    #
    # - +:direction+ - Default is +:up+.
    # - +:revert+ - Default is +false+.
    def run(*migration_classes)
      opts = migration_classes.extract_options!
      dir = opts[:direction] || :up
      dir = (dir == :down ? :up : :down) if opts[:revert]
      if reverting?
        # If in revert and going :up, say, we want to execute :down without reverting, so
        revert { run(*migration_classes, direction: dir, revert: true) }
      else
        migration_classes.each do |migration_class|
          migration_class.new.exec_migration(connection, dir)
        end
      end
    end

    def up
      self.class.delegate = self
      return unless self.class.respond_to?(:up)
      self.class.up
    end

    def down
      self.class.delegate = self
      return unless self.class.respond_to?(:down)
      self.class.down
    end

    # Execute this migration in the named direction
    def migrate(direction)
      return unless respond_to?(direction)

      case direction
      when :up   then announce "migrating"
      when :down then announce "reverting"
      end

      time_elapsed = nil
      ActiveRecord::Tasks::DatabaseTasks.migration_connection.pool.with_connection do |conn|
        time_elapsed = ActiveSupport::Benchmark.realtime do
          exec_migration(conn, direction)
        end
      end

      case direction
      when :up   then announce "migrated (%.4fs)" % time_elapsed; write
      when :down then announce "reverted (%.4fs)" % time_elapsed; write
      end
    end

    def exec_migration(conn, direction)
      @connection = conn
      if respond_to?(:change)
        if direction == :down
          revert { change }
        else
          change
        end
      else
        public_send(direction)
      end
    ensure
      @connection = nil
      @execution_strategy = nil
    end

    def write(text = "")
      puts(text) if verbose
    end

    def announce(message)
      text = "#{version} #{name}: #{message}"
      length = [0, 75 - text.length].max
      write "== %s %s" % [text, "=" * length]
    end

    # Takes a message argument and outputs it as is.
    # A second boolean argument can be passed to specify whether to indent or not.
    def say(message, subitem = false)
      write "#{subitem ? "   ->" : "--"} #{message}"
    end

    # Outputs text along with how long it took to run its block.
    # If the block returns an integer it assumes it is the number of rows affected.
    def say_with_time(message)
      say(message)
      result = nil
      time_elapsed = ActiveSupport::Benchmark.realtime { result = yield }
      say "%.4fs" % time_elapsed, :subitem
      say("#{result} rows", :subitem) if result.is_a?(Integer)
      result
    end

    # Takes a block as an argument and suppresses any output generated by the block.
    def suppress_messages
      save, self.verbose = verbose, false
      yield
    ensure
      self.verbose = save
    end

    def connection
      @connection || ActiveRecord::Tasks::DatabaseTasks.migration_connection
    end

    def connection_pool
      @pool || ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
    end

    def method_missing(method, *arguments, &block)
      say_with_time "#{method}(#{format_arguments(arguments)})" do
        unless connection.respond_to? :revert
          unless arguments.empty? || [:execute, :enable_extension, :disable_extension].include?(method)
            arguments[0] = proper_table_name(arguments.first, table_name_options)
            if method == :rename_table ||
              (method == :remove_foreign_key && !arguments.second.is_a?(Hash))
              arguments[1] = proper_table_name(arguments.second, table_name_options)
            end
          end
        end
        return super unless execution_strategy.respond_to?(method)
        execution_strategy.send(method, *arguments, &block)
      end
    end
    ruby2_keywords(:method_missing)

    def copy(destination, sources, options = {})
      copied = []

      FileUtils.mkdir_p(destination) unless File.exist?(destination)
      schema_migration = SchemaMigration::NullSchemaMigration.new
      internal_metadata = InternalMetadata::NullInternalMetadata.new

      destination_migrations = ActiveRecord::MigrationContext.new(destination, schema_migration, internal_metadata).migrations
      last = destination_migrations.last
      sources.each do |scope, path|
        source_migrations = ActiveRecord::MigrationContext.new(path, schema_migration, internal_metadata).migrations

        source_migrations.each do |migration|
          source = File.binread(migration.filename)
          inserted_comment = "# This migration comes from #{scope} (originally #{migration.version})\n"
          magic_comments = +""
          loop do
            # If we have a magic comment in the original migration,
            # insert our comment after the first newline(end of the magic comment line)
            # so the magic keep working.
            # Note that magic comments must be at the first line(except sh-bang).
            source.sub!(/\A(?:#.*\b(?:en)?coding:\s*\S+|#\s*frozen_string_literal:\s*(?:true|false)).*\n/) do |magic_comment|
              magic_comments << magic_comment; ""
            end || break
          end

          if !magic_comments.empty? && source.start_with?("\n")
            magic_comments << "\n"
            source = source[1..-1]
          end

          source = "#{magic_comments}#{inserted_comment}#{source}"

          if duplicate = destination_migrations.detect { |m| m.name == migration.name }
            if options[:on_skip] && duplicate.scope != scope.to_s
              options[:on_skip].call(scope, migration)
            end
            next
          end

          migration.version = next_migration_number(last ? last.version + 1 : 0).to_i
          new_path = File.join(destination, "#{migration.version}_#{migration.name.underscore}.#{scope}.rb")
          old_path, migration.filename = migration.filename, new_path
          last = migration

          File.binwrite(migration.filename, source)
          copied << migration
          options[:on_copy].call(scope, migration, old_path) if options[:on_copy]
          destination_migrations << migration
        end
      end

      copied
    end

    # Finds the correct table name given an Active Record object.
    # Uses the Active Record object's own table_name, or pre/suffix from the
    # options passed in.
    def proper_table_name(name, options = {})
      if name.respond_to? :table_name
        name.table_name
      else
        "#{options[:table_name_prefix]}#{name}#{options[:table_name_suffix]}"
      end
    end

    # Determines the version number of the next migration.
    def next_migration_number(number)
      if ActiveRecord.timestamped_migrations
        [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % number].max
      else
        "%.3d" % number.to_i
      end
    end

    # Builds a hash for use in ActiveRecord::Migration#proper_table_name using
    # the Active Record object's table_name prefix and suffix
    def table_name_options(config = ActiveRecord::Base) # :nodoc:
      {
        table_name_prefix: config.table_name_prefix,
        table_name_suffix: config.table_name_suffix
      }
    end

    private
      def execute_block
        if connection.respond_to? :execute_block
          super # use normal delegation to record the block
        else
          yield
        end
      end

      def format_arguments(arguments)
        arg_list = arguments[0...-1].map(&:inspect)
        last_arg = arguments.last
        if last_arg.is_a?(Hash)
          last_arg = last_arg.reject { |k, _v| internal_option?(k) }
          arg_list << last_arg.inspect unless last_arg.empty?
        else
          arg_list << last_arg.inspect
        end
        arg_list.join(", ")
      end

      def internal_option?(option_name)
        option_name.start_with?("_")
      end

      def command_recorder
        CommandRecorder.new(connection)
      end
  end

  # MigrationProxy is used to defer loading of the actual migration classes
  # until they are needed
  MigrationProxy = Struct.new(:name, :version, :filename, :scope) do
    def initialize(name, version, filename, scope)
      super
      @migration = nil
    end

    def basename
      File.basename(filename)
    end

    delegate :migrate, :announce, :write, :disable_ddl_transaction, to: :migration

    private
      def migration
        @migration ||= load_migration
      end

      def load_migration
        Object.send(:remove_const, name) rescue nil

        load(File.expand_path(filename))
        name.constantize.new(name, version)
      end
  end

  # = \Migration \Context
  #
  # MigrationContext sets the context in which a migration is run.
  #
  # A migration context requires the path to the migrations is set
  # in the +migrations_paths+ parameter. Optionally a +schema_migration+
  # class can be provided. Multiple database applications will instantiate
  # a +SchemaMigration+ object per database. From the Rake tasks, \Rails will
  # handle this for you.
  class MigrationContext
    attr_reader :migrations_paths, :schema_migration, :internal_metadata

    def initialize(migrations_paths, schema_migration = nil, internal_metadata = nil)
      @migrations_paths = migrations_paths
      @schema_migration = schema_migration || SchemaMigration.new(connection_pool)
      @internal_metadata = internal_metadata || InternalMetadata.new(connection_pool)
    end

    # Runs the migrations in the +migrations_path+.
    #
    # If +target_version+ is +nil+, +migrate+ will run +up+.
    #
    # If the +current_version+ and +target_version+ are both
    # 0 then an empty array will be returned and no migrations
    # will be run.
    #
    # If the +current_version+ in the schema is greater than
    # the +target_version+, then +down+ will be run.
    #
    # If none of the conditions are met, +up+ will be run with
    # the +target_version+.
    def migrate(target_version = nil, &block)
      case
      when target_version.nil?
        up(target_version, &block)
      when current_version == 0 && target_version == 0
        []
      when current_version > target_version
        down(target_version, &block)
      else
        up(target_version, &block)
      end
    end

    def rollback(steps = 1) # :nodoc:
      move(:down, steps)
    end

    def forward(steps = 1) # :nodoc:
      move(:up, steps)
    end

    def up(target_version = nil, &block) # :nodoc:
      selected_migrations = if block_given?
        migrations.select(&block)
      else
        migrations
      end

      Migrator.new(:up, selected_migrations, schema_migration, internal_metadata, target_version).migrate
    end

    def down(target_version = nil, &block) # :nodoc:
      selected_migrations = if block_given?
        migrations.select(&block)
      else
        migrations
      end

      Migrator.new(:down, selected_migrations, schema_migration, internal_metadata, target_version).migrate
    end

    def run(direction, target_version) # :nodoc:
      Migrator.new(direction, migrations, schema_migration, internal_metadata, target_version).run
    end

    def open # :nodoc:
      Migrator.new(:up, migrations, schema_migration, internal_metadata)
    end

    def get_all_versions # :nodoc:
      if schema_migration.table_exists?
        schema_migration.integer_versions
      else
        []
      end
    end

    def current_version # :nodoc:
      get_all_versions.max || 0
    rescue ActiveRecord::NoDatabaseError
    end

    def needs_migration? # :nodoc:
      pending_migration_versions.size > 0
    end

    def pending_migration_versions # :nodoc:
      migrations.collect(&:version) - get_all_versions
    end

    def migrations # :nodoc:
      migrations = migration_files.map do |file|
        version, name, scope = parse_migration_filename(file)
        raise IllegalMigrationNameError.new(file) unless version
        if validate_timestamp? && !valid_migration_timestamp?(version)
          raise InvalidMigrationTimestampError.new(version, name)
        end
        version = version.to_i
        name = name.camelize

        MigrationProxy.new(name, version, file, scope)
      end

      migrations.sort_by(&:version)
    end

    def migrations_status # :nodoc:
      db_list = schema_migration.normalized_versions

      file_list = migration_files.filter_map do |file|
        version, name, scope = parse_migration_filename(file)
        raise IllegalMigrationNameError.new(file) unless version
        if validate_timestamp? && !valid_migration_timestamp?(version)
          raise InvalidMigrationTimestampError.new(version, name)
        end
        version = schema_migration.normalize_migration_number(version)
        status = db_list.delete(version) ? "up" : "down"
        [status, version, (name + scope).humanize]
      end

      db_list.map! do |version|
        ["up", version, "********** NO FILE **********"]
      end

      (db_list + file_list).sort_by { |_, version, _| version.to_i }
    end

    def current_environment # :nodoc:
      ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
    end

    def protected_environment? # :nodoc:
      ActiveRecord::Base.protected_environments.include?(last_stored_environment) if last_stored_environment
    end

    def last_stored_environment # :nodoc:
      internal_metadata = connection_pool.internal_metadata
      return nil unless internal_metadata.enabled?
      return nil if current_version == 0
      raise NoEnvironmentInSchemaError unless internal_metadata.table_exists?

      environment = internal_metadata[:environment]
      raise NoEnvironmentInSchemaError unless environment
      environment
    end

    private
      def connection
        ActiveRecord::Tasks::DatabaseTasks.migration_connection
      end

      def connection_pool
        ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
      end

      def migration_files
        paths = Array(migrations_paths)
        Dir[*paths.flat_map { |path| "#{path}/**/[0-9]*_*.rb" }]
      end

      def parse_migration_filename(filename)
        File.basename(filename).scan(Migration::MigrationFilenameRegexp).first
      end

      def validate_timestamp?
        ActiveRecord.timestamped_migrations && ActiveRecord.validate_migration_timestamps
      end

      def valid_migration_timestamp?(version)
        version.to_i < (Time.now.utc + 1.day).strftime("%Y%m%d%H%M%S").to_i
      end

      def move(direction, steps)
        migrator = Migrator.new(direction, migrations, schema_migration, internal_metadata)

        if current_version != 0 && !migrator.current_migration
          raise UnknownMigrationVersionError.new(current_version)
        end

        start_index =
          if current_version == 0
            0
          else
            migrator.migrations.index(migrator.current_migration)
          end

        finish = migrator.migrations[start_index + steps]
        version = finish ? finish.version : 0
        public_send(direction, version)
      end
  end

  class Migrator # :nodoc:
    class << self
      attr_accessor :migrations_paths

      # For cases where a table doesn't exist like loading from schema cache
      def current_version
        connection_pool = ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
        schema_migration = SchemaMigration.new(connection_pool)
        internal_metadata = InternalMetadata.new(connection_pool)

        MigrationContext.new(migrations_paths, schema_migration, internal_metadata).current_version
      end
    end

    self.migrations_paths = ["db/migrate"]

    def initialize(direction, migrations, schema_migration, internal_metadata, target_version = nil)
      @direction         = direction
      @target_version    = target_version
      @migrated_versions = nil
      @migrations        = migrations
      @schema_migration  = schema_migration
      @internal_metadata = internal_metadata

      validate(@migrations)

      @schema_migration.create_table
      @internal_metadata.create_table
    end

    def current_version
      migrated.max || 0
    end

    def current_migration
      migrations.detect { |m| m.version == current_version }
    end
    alias :current :current_migration

    def run
      if use_advisory_lock?
        with_advisory_lock { run_without_lock }
      else
        run_without_lock
      end
    end

    def migrate
      if use_advisory_lock?
        with_advisory_lock { migrate_without_lock }
      else
        migrate_without_lock
      end
    end

    def runnable
      runnable = migrations[start..finish]
      if up?
        runnable.reject { |m| ran?(m) }
      else
        # skip the last migration if we're headed down, but not ALL the way down
        runnable.pop if target
        runnable.find_all { |m| ran?(m) }
      end
    end

    def migrations
      down? ? @migrations.reverse : @migrations.sort_by(&:version)
    end

    def pending_migrations
      already_migrated = migrated
      migrations.reject { |m| already_migrated.include?(m.version) }
    end

    def migrated
      @migrated_versions || load_migrated
    end

    def load_migrated
      @migrated_versions = Set.new(@schema_migration.integer_versions)
    end

    private
      def connection
        ActiveRecord::Tasks::DatabaseTasks.migration_connection
      end

      # Used for running a specific migration.
      def run_without_lock
        migration = migrations.detect { |m| m.version == @target_version }
        raise UnknownMigrationVersionError.new(@target_version) if migration.nil?

        record_environment
        execute_migration_in_transaction(migration)
      end

      # Used for running multiple migrations up to or down to a certain value.
      def migrate_without_lock
        if invalid_target?
          raise UnknownMigrationVersionError.new(@target_version)
        end

        record_environment
        runnable.each(&method(:execute_migration_in_transaction))
      end

      # Stores the current environment in the database.
      def record_environment
        return if down?

        @internal_metadata[:environment] = connection.pool.db_config.env_name
      end

      def ran?(migration)
        migrated.include?(migration.version.to_i)
      end

      # Return true if a valid version is not provided.
      def invalid_target?
        @target_version && @target_version != 0 && !target
      end

      def execute_migration_in_transaction(migration)
        return if down? && !migrated.include?(migration.version.to_i)
        return if up?   &&  migrated.include?(migration.version.to_i)

        Base.logger.info "Migrating to #{migration.name} (#{migration.version})" if Base.logger

        ddl_transaction(migration) do
          migration.migrate(@direction)
          record_version_state_after_migrating(migration.version)
        end
      rescue => e
        msg = +"An error has occurred, "
        msg << "this and " if use_transaction?(migration)
        msg << "all later migrations canceled:\n\n#{e}"
        raise StandardError, msg, e.backtrace
      end

      def target
        migrations.detect { |m| m.version == @target_version }
      end

      def finish
        migrations.index(target) || migrations.size - 1
      end

      def start
        up? ? 0 : (migrations.index(current) || 0)
      end

      def validate(migrations)
        name, = migrations.group_by(&:name).find { |_, v| v.length > 1 }
        raise DuplicateMigrationNameError.new(name) if name

        version, = migrations.group_by(&:version).find { |_, v| v.length > 1 }
        raise DuplicateMigrationVersionError.new(version) if version
      end

      def record_version_state_after_migrating(version)
        if down?
          migrated.delete(version)
          @schema_migration.delete_version(version.to_s)
        else
          migrated << version
          @schema_migration.create_version(version.to_s)
        end
      end

      def up?
        @direction == :up
      end

      def down?
        @direction == :down
      end

      # Wrap the migration in a transaction only if supported by the adapter.
      def ddl_transaction(migration, &block)
        if use_transaction?(migration)
          connection.transaction(&block)
        else
          yield
        end
      end

      def use_transaction?(migration)
        !migration.disable_ddl_transaction && connection.supports_ddl_transactions?
      end

      def use_advisory_lock?
        connection.advisory_locks_enabled?
      end

      def with_advisory_lock
        lock_id = generate_migrator_advisory_lock_id

        got_lock = connection.get_advisory_lock(lock_id)
        raise ConcurrentMigrationError unless got_lock
        load_migrated # reload schema_migrations to be sure it wasn't changed by another process before we got the lock
        yield
      ensure
        if got_lock && !connection.release_advisory_lock(lock_id)
          raise ConcurrentMigrationError.new(
            ConcurrentMigrationError::RELEASE_LOCK_FAILED_MESSAGE
          )
        end
      end

      MIGRATOR_SALT = 2053462845
      def generate_migrator_advisory_lock_id
        db_name_hash = Zlib.crc32(connection.current_database)
        MIGRATOR_SALT * db_name_hash
      end
  end
end
