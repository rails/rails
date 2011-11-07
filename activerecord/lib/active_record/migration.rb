require "active_support/core_ext/module/delegation"
require "active_support/core_ext/class/attribute_accessors"
require "active_support/core_ext/array/wrap"

module ActiveRecord
  # Exception that can be raised to stop migrations from going backwards.
  class IrreversibleMigration < ActiveRecordError
  end

  class DuplicateMigrationVersionError < ActiveRecordError#:nodoc:
    def initialize(version)
      super("Multiple migrations have the version number #{version}")
    end
  end

  class DuplicateMigrationNameError < ActiveRecordError#:nodoc:
    def initialize(name)
      super("Multiple migrations have the name #{name}")
    end
  end

  class UnknownMigrationVersionError < ActiveRecordError #:nodoc:
    def initialize(version)
      super("No migration with version number #{version}")
    end
  end

  class IllegalMigrationNameError < ActiveRecordError#:nodoc:
    def initialize(name)
      super("Illegal name for migration file: #{name}\n\t(only lower case letters, numbers, and '_' allowed)")
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
  #   class AddSsl < ActiveRecord::Migration
  #     def up
  #       add_column :accounts, :ssl_enabled, :boolean, :default => 1
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
  # of both the migration specific methods like add_column and remove_column,
  # but may also contain regular Ruby code for generating data needed for the
  # transformations.
  #
  # Example of a more complex migration that also needs to initialize data:
  #
  #   class AddSystemSettings < ActiveRecord::Migration
  #     def up
  #       create_table :system_settings do |t|
  #         t.string  :name
  #         t.string  :label
  #         t.text  :value
  #         t.string  :type
  #         t.integer  :position
  #       end
  #
  #       SystemSetting.create  :name => "notice",
  #                             :label => "Use notice?",
  #                             :value => 1
  #     end
  #
  #     def down
  #       drop_table :system_settings
  #     end
  #   end
  #
  # This migration first adds the system_settings table, then creates the very
  # first row in it using the Active Record model that relies on the table. It
  # also uses the more advanced create_table syntax where you can specify a
  # complete table schema in one block call.
  #
  # == Available transformations
  #
  # * <tt>create_table(name, options)</tt> Creates a table called +name+ and
  #   makes the table object available to a block that can then add columns to it,
  #   following the same format as add_column. See example above. The options hash
  #   is for fragments like "DEFAULT CHARSET=UTF-8" that are appended to the create
  #   table definition.
  # * <tt>drop_table(name)</tt>: Drops the table called +name+.
  # * <tt>rename_table(old_name, new_name)</tt>: Renames the table called +old_name+
  #   to +new_name+.
  # * <tt>add_column(table_name, column_name, type, options)</tt>: Adds a new column
  #   to the table called +table_name+
  #   named +column_name+ specified to be one of the following types:
  #   <tt>:string</tt>, <tt>:text</tt>, <tt>:integer</tt>, <tt>:float</tt>,
  #   <tt>:decimal</tt>, <tt>:datetime</tt>, <tt>:timestamp</tt>, <tt>:time</tt>,
  #   <tt>:date</tt>, <tt>:binary</tt>, <tt>:boolean</tt>. A default value can be
  #   specified by passing an +options+ hash like <tt>{ :default => 11 }</tt>.
  #   Other options include <tt>:limit</tt> and <tt>:null</tt> (e.g.
  #   <tt>{ :limit => 50, :null => false }</tt>) -- see
  #   ActiveRecord::ConnectionAdapters::TableDefinition#column for details.
  # * <tt>rename_column(table_name, column_name, new_column_name)</tt>: Renames
  #   a column but keeps the type and content.
  # * <tt>change_column(table_name, column_name, type, options)</tt>:  Changes
  #   the column to a different type using the same parameters as add_column.
  # * <tt>remove_column(table_name, column_names)</tt>: Removes the column listed in
  #   +column_names+ from the table called +table_name+.
  # * <tt>add_index(table_name, column_names, options)</tt>: Adds a new index
  #   with the name of the column. Other options include
  #   <tt>:name</tt> and <tt>:unique</tt> (e.g.
  #   <tt>{ :name => "users_name_index", :unique => true }</tt>).
  # * <tt>remove_index(table_name, :column => column_name)</tt>: Removes the index
  #   specified by +column_name+.
  # * <tt>remove_index(table_name, :name => index_name)</tt>: Removes the index
  #   specified by +index_name+.
  #
  # == Irreversible transformations
  #
  # Some transformations are destructive in a manner that cannot be reversed.
  # Migrations of that kind should raise an <tt>ActiveRecord::IrreversibleMigration</tt>
  # exception in their +down+ method.
  #
  # == Running migrations from within Rails
  #
  # The Rails package has several tools to help create and apply migrations.
  #
  # To generate a new migration, you can use
  #   rails generate migration MyNewMigration
  #
  # where MyNewMigration is the name of your migration. The generator will
  # create an empty migration file <tt>timestamp_my_new_migration.rb</tt>
  # in the <tt>db/migrate/</tt> directory where <tt>timestamp</tt> is the
  # UTC formatted date and time that the migration was generated.
  #
  # You may then edit the <tt>up</tt> and <tt>down</tt> methods of
  # MyNewMigration.
  #
  # There is a special syntactic shortcut to generate migrations that add fields to a table.
  #
  #   rails generate migration add_fieldname_to_tablename fieldname:string
  #
  # This will generate the file <tt>timestamp_add_fieldname_to_tablename</tt>, which will look like this:
  #   class AddFieldnameToTablename < ActiveRecord::Migration
  #     def up
  #       add_column :tablenames, :fieldname, :string
  #     end
  #
  #     def down
  #       remove_column :tablenames, :fieldname
  #     end
  #   end
  #
  # To run migrations against the currently configured database, use
  # <tt>rake db:migrate</tt>. This will update the database by running all of the
  # pending migrations, creating the <tt>schema_migrations</tt> table
  # (see "About the schema_migrations table" section below) if missing. It will also
  # invoke the db:schema:dump task, which will update your db/schema.rb file
  # to match the structure of your database.
  #
  # To roll the database back to a previous migration version, use
  # <tt>rake db:migrate VERSION=X</tt> where <tt>X</tt> is the version to which
  # you wish to downgrade. If any of the migrations throw an
  # <tt>ActiveRecord::IrreversibleMigration</tt> exception, that step will fail and you'll
  # have some manual work to do.
  #
  # == Database support
  #
  # Migrations are currently supported in MySQL, PostgreSQL, SQLite,
  # SQL Server, Sybase, and Oracle (all supported databases except DB2).
  #
  # == More examples
  #
  # Not all migrations change the schema. Some just fix the data:
  #
  #   class RemoveEmptyTags < ActiveRecord::Migration
  #     def up
  #       Tag.find(:all).each { |tag| tag.destroy if tag.pages.empty? }
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
  #   class RemoveUnnecessaryItemAttributes < ActiveRecord::Migration
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
  #   class MakeJoinUnique < ActiveRecord::Migration
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
  #   class AddPeopleSalary < ActiveRecord::Migration
  #     def up
  #       add_column :people, :salary, :integer
  #       Person.reset_column_information
  #       Person.find(:all).each do |p|
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
  # You can quiet them down by setting ActiveRecord::Migration.verbose = false.
  #
  # You can also insert your own messages and benchmarks by using the +say_with_time+
  # method:
  #
  #   def up
  #     ...
  #     say_with_time "Updating salaries..." do
  #       Person.find(:all).each do |p|
  #         p.update_attribute :salary, SalaryCalculator.compute(p)
  #       end
  #     end
  #     ...
  #   end
  #
  # The phrase "Updating salaries..." would then be printed, along with the
  # benchmark for the block when the block completes.
  #
  # == About the schema_migrations table
  #
  # Rails versions 2.0 and prior used to create a table called
  # <tt>schema_info</tt> when using migrations. This table contained the
  # version of the schema as of the last applied migration.
  #
  # Starting with Rails 2.1, the <tt>schema_info</tt> table is
  # (automatically) replaced by the <tt>schema_migrations</tt> table, which
  # contains the version numbers of all the migrations applied.
  #
  # As a result, it is now possible to add migration files that are numbered
  # lower than the current schema version: when migrating up, those
  # never-applied "interleaved" migrations will be automatically applied, and
  # when migrating down, never-applied "interleaved" migrations will be skipped.
  #
  # == Timestamped Migrations
  #
  # By default, Rails generates migrations that look like:
  #
  #    20080717013526_your_migration_name.rb
  #
  # The prefix is a generation timestamp (in UTC).
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
  # Starting with Rails 3.1, you will be able to define reversible migrations.
  # Reversible migrations are migrations that know how to go +down+ for you.
  # You simply supply the +up+ logic, and the Migration system will figure out
  # how to execute the down commands for you.
  #
  # To define a reversible migration, define the +change+ method in your
  # migration like this:
  #
  #   class TenderloveMigration < ActiveRecord::Migration
  #     def change
  #       create_table(:horses) do
  #         t.column :content, :text
  #         t.column :remind_at, :datetime
  #       end
  #     end
  #   end
  #
  # This migration will create the horses table for you on the way up, and
  # automatically figure out how to drop the table on the way down.
  #
  # Some commands like +remove_column+ cannot be reversed.  If you care to
  # define how to move up and down in these cases, you should define the +up+
  # and +down+ methods as before.
  #
  # If a command cannot be reversed, an
  # <tt>ActiveRecord::IrreversibleMigration</tt> exception will be raised when
  # the migration is moving down.
  #
  # For a list of commands that are reversible, please see
  # <tt>ActiveRecord::Migration::CommandRecorder</tt>.
  class Migration
    autoload :CommandRecorder, 'active_record/migration/command_recorder'

    class << self
      attr_accessor :delegate # :nodoc:
    end

    def self.method_missing(name, *args, &block) # :nodoc:
      (delegate || superclass.delegate).send(name, *args, &block)
    end

    def self.migrate(direction)
      new.migrate direction
    end

    cattr_accessor :verbose

    attr_accessor :name, :version

    def initialize
      @name       = self.class.name
      @version    = nil
      @connection = nil
    end

    # instantiate the delegate object after initialize is defined
    self.verbose  = true
    self.delegate = new

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

      time   = nil
      ActiveRecord::Base.connection_pool.with_connection do |conn|
        @connection = conn
        if respond_to?(:change)
          if direction == :down
            recorder = CommandRecorder.new(@connection)
            suppress_messages do
              @connection = recorder
              change
            end
            @connection = conn
            time = Benchmark.measure {
              recorder.inverse.each do |cmd, args|
                send(cmd, *args)
              end
            }
          else
            time = Benchmark.measure { change }
          end
        else
          time = Benchmark.measure { send(direction) }
        end
        @connection = nil
      end

      case direction
      when :up   then announce "migrated (%.4fs)" % time.real; write
      when :down then announce "reverted (%.4fs)" % time.real; write
      end
    end

    def write(text="")
      puts(text) if verbose
    end

    def announce(message)
      text = "#{version} #{name}: #{message}"
      length = [0, 75 - text.length].max
      write "== %s %s" % [text, "=" * length]
    end

    def say(message, subitem=false)
      write "#{subitem ? "   ->" : "--"} #{message}"
    end

    def say_with_time(message)
      say(message)
      result = nil
      time = Benchmark.measure { result = yield }
      say "%.4fs" % time.real, :subitem
      say("#{result} rows", :subitem) if result.is_a?(Integer)
      result
    end

    def suppress_messages
      save, self.verbose = verbose, false
      yield
    ensure
      self.verbose = save
    end

    def connection
      @connection || ActiveRecord::Base.connection
    end

    def method_missing(method, *arguments, &block)
      arg_list = arguments.map{ |a| a.inspect } * ', '

      say_with_time "#{method}(#{arg_list})" do
        unless arguments.empty? || method == :execute
          arguments[0] = Migrator.proper_table_name(arguments.first)
        end
        return super unless connection.respond_to?(method)
        connection.send(method, *arguments, &block)
      end
    end

    def copy(destination, sources, options = {})
      copied = []

      FileUtils.mkdir_p(destination) unless File.exists?(destination)

      destination_migrations = ActiveRecord::Migrator.migrations(destination)
      last = destination_migrations.last
      sources.each do |name, path|
        source_migrations = ActiveRecord::Migrator.migrations(path)

        source_migrations.each do |migration|
          source = File.read(migration.filename)
          source = "# This migration comes from #{name} (originally #{migration.version})\n#{source}"

          if duplicate = destination_migrations.detect { |m| m.name == migration.name }
            options[:on_skip].call(name, migration) if File.read(duplicate.filename) != source && options[:on_skip]
            next
          end

          migration.version = next_migration_number(last ? last.version + 1 : 0).to_i
          new_path = File.join(destination, "#{migration.version}_#{migration.name.underscore}.rb")
          old_path, migration.filename = migration.filename, new_path
          last = migration

          FileUtils.cp(old_path, migration.filename)
          copied << migration
          options[:on_copy].call(name, migration, old_path) if options[:on_copy]
          destination_migrations << migration
        end
      end

      copied
    end

    def next_migration_number(number)
      if ActiveRecord::Base.timestamped_migrations
        [Time.now.utc.strftime("%Y%m%d%H%M%S"), "%.14d" % number].max
      else
        "%.3d" % number
      end
    end
  end

  # MigrationProxy is used to defer loading of the actual migration classes
  # until they are needed
  class MigrationProxy < Struct.new(:name, :version, :filename)

    def initialize(name, version, filename)
      super
      @migration = nil
    end

    def basename
      File.basename(filename)
    end

    delegate :migrate, :announce, :write, :to=>:migration

    private

      def migration
        @migration ||= load_migration
      end

      def load_migration
        require(File.expand_path(filename))
        name.constantize.new
      end

  end

  class Migrator#:nodoc:
    class << self
      attr_writer :migrations_paths
      alias :migrations_path= :migrations_paths=

      def migrate(migrations_paths, target_version = nil)
        case
          when target_version.nil?
            up(migrations_paths, target_version)
          when current_version == 0 && target_version == 0
            []
          when current_version > target_version
            down(migrations_paths, target_version)
          else
            up(migrations_paths, target_version)
        end
      end

      def rollback(migrations_paths, steps=1)
        move(:down, migrations_paths, steps)
      end

      def forward(migrations_paths, steps=1)
        move(:up, migrations_paths, steps)
      end

      def up(migrations_paths, target_version = nil)
        self.new(:up, migrations_paths, target_version).migrate
      end

      def down(migrations_paths, target_version = nil)
        self.new(:down, migrations_paths, target_version).migrate
      end

      def run(direction, migrations_paths, target_version)
        self.new(direction, migrations_paths, target_version).run
      end

      def schema_migrations_table_name
        Base.table_name_prefix + 'schema_migrations' + Base.table_name_suffix
      end

      def get_all_versions
        table = Arel::Table.new(schema_migrations_table_name)
        Base.connection.select_values(table.project(table['version'])).map{ |v| v.to_i }.sort
      end

      def current_version
        sm_table = schema_migrations_table_name
        if Base.connection.table_exists?(sm_table)
          get_all_versions.max || 0
        else
          0
        end
      end

      def proper_table_name(name)
        # Use the Active Record objects own table_name, or pre/suffix from ActiveRecord::Base if name is a symbol/string
        name.table_name rescue "#{ActiveRecord::Base.table_name_prefix}#{name}#{ActiveRecord::Base.table_name_suffix}"
      end

      def migrations_paths
        @migrations_paths ||= ['db/migrate']
        # just to not break things if someone uses: migration_path = some_string
        Array.wrap(@migrations_paths)
      end

      def migrations_path
        migrations_paths.first
      end

      def migrations(paths)
        paths = Array.wrap(paths)

        files = Dir[*paths.map { |p| "#{p}/[0-9]*_*.rb" }]

        seen = Hash.new false

        migrations = files.map do |file|
          version, name = file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first

          raise IllegalMigrationNameError.new(file) unless version
          version = version.to_i
          name = name.camelize

          raise DuplicateMigrationVersionError.new(version) if seen[version]
          raise DuplicateMigrationNameError.new(name) if seen[name]

          seen[version] = seen[name] = true

          MigrationProxy.new(name, version, file)
        end

        migrations.sort_by(&:version)
      end

      private

      def move(direction, migrations_paths, steps)
        migrator = self.new(direction, migrations_paths)
        start_index = migrator.migrations.index(migrator.current_migration)

        if start_index
          finish = migrator.migrations[start_index + steps]
          version = finish ? finish.version : 0
          send(direction, migrations_paths, version)
        end
      end
    end

    def initialize(direction, migrations_paths, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      Base.connection.initialize_schema_migrations_table
      @direction, @migrations_paths, @target_version = direction, migrations_paths, target_version
    end

    def current_version
      migrated.last || 0
    end

    def current_migration
      migrations.detect { |m| m.version == current_version }
    end

    def run
      target = migrations.detect { |m| m.version == @target_version }
      raise UnknownMigrationVersionError.new(@target_version) if target.nil?
      unless (up? && migrated.include?(target.version.to_i)) || (down? && !migrated.include?(target.version.to_i))
        target.migrate(@direction)
        record_version_state_after_migrating(target.version)
      end
    end

    def migrate
      current = migrations.detect { |m| m.version == current_version }
      target = migrations.detect { |m| m.version == @target_version }

      if target.nil? && @target_version && @target_version > 0
        raise UnknownMigrationVersionError.new(@target_version)
      end

      start = up? ? 0 : (migrations.index(current) || 0)
      finish = migrations.index(target) || migrations.size - 1
      runnable = migrations[start..finish]

      # skip the last migration if we're headed down, but not ALL the way down
      runnable.pop if down? && target

      ran = []
      runnable.each do |migration|
        Base.logger.info "Migrating to #{migration.name} (#{migration.version})" if Base.logger

        seen = migrated.include?(migration.version.to_i)

        # On our way up, we skip migrating the ones we've already migrated
        next if up? && seen

        # On our way down, we skip reverting the ones we've never migrated
        if down? && !seen
          migration.announce 'never migrated, skipping'; migration.write
          next
        end

        begin
          ddl_transaction do
            migration.migrate(@direction)
            record_version_state_after_migrating(migration.version)
          end
          ran << migration
        rescue => e
          canceled_msg = Base.connection.supports_ddl_transactions? ? "this and " : ""
          raise StandardError, "An error has occurred, #{canceled_msg}all later migrations canceled:\n\n#{e}", e.backtrace
        end
      end
      ran
    end

    def migrations
      @migrations ||= begin
        migrations = self.class.migrations(@migrations_paths)
        down? ? migrations.reverse : migrations
      end
    end

    def pending_migrations
      already_migrated = migrated
      migrations.reject { |m| already_migrated.include?(m.version.to_i) }
    end

    def migrated
      @migrated_versions ||= self.class.get_all_versions
    end

    private
      def record_version_state_after_migrating(version)
        table = Arel::Table.new(self.class.schema_migrations_table_name)

        @migrated_versions ||= []
        if down?
          @migrated_versions.delete(version)
          stmt = table.where(table["version"].eq(version.to_s)).compile_delete
          Base.connection.delete stmt
        else
          @migrated_versions.push(version).sort!
          stmt = table.compile_insert table["version"] => version.to_s
          Base.connection.insert stmt
        end
      end

      def up?
        @direction == :up
      end

      def down?
        @direction == :down
      end

      # Wrap the migration in a transaction only if supported by the adapter.
      def ddl_transaction(&block)
        if Base.connection.supports_ddl_transactions?
          Base.transaction { block.call }
        else
          block.call
        end
      end
  end
end
