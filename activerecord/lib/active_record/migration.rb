module ActiveRecord
  class IrreversibleMigration < ActiveRecordError#:nodoc:
  end

  class DuplicateMigrationVersionError < ActiveRecordError#:nodoc:
    def initialize(version)
      super("Multiple migrations have the version number #{version}")
    end
  end

  # Migrations can manage the evolution of a schema used by several physical databases. It's a solution
  # to the common problem of adding a field to make a new feature work in your local database, but being unsure of how to
  # push that change to other developers and to the production server. With migrations, you can describe the transformations
  # in self-contained classes that can be checked into version control systems and executed against another database that
  # might be one, two, or five versions behind.
  #
  # Example of a simple migration:
  #
  #   class AddSsl < ActiveRecord::Migration
  #     def self.up
  #       add_column :accounts, :ssl_enabled, :boolean, :default => 1
  #     end
  #
  #     def self.down
  #       remove_column :accounts, :ssl_enabled
  #     end
  #   end
  #
  # This migration will add a boolean flag to the accounts table and remove it again, if you're backing out of the migration.
  # It shows how all migrations have two class methods +up+ and +down+ that describes the transformations required to implement
  # or remove the migration. These methods can consist of both the migration specific methods, like add_column and remove_column,
  # but may also contain regular Ruby code for generating data needed for the transformations.
  #
  # Example of a more complex migration that also needs to initialize data:
  #
  #   class AddSystemSettings < ActiveRecord::Migration
  #     def self.up
  #       create_table :system_settings do |t|
  #         t.column :name,     :string
  #         t.column :label,    :string
  #         t.column :value,    :text
  #         t.column :type,     :string
  #         t.column :position, :integer
  #       end
  #
  #       SystemSetting.create :name => "notice", :label => "Use notice?", :value => 1
  #     end
  #
  #     def self.down
  #       drop_table :system_settings
  #     end
  #   end
  #
  # This migration first adds the system_settings table, then creates the very first row in it using the Active Record model
  # that relies on the table. It also uses the more advanced create_table syntax where you can specify a complete table schema
  # in one block call.
  #
  # == Available transformations
  #
  # * <tt>create_table(name, options)</tt> Creates a table called +name+ and makes the table object available to a block
  #   that can then add columns to it, following the same format as add_column. See example above. The options hash is for
  #   fragments like "DEFAULT CHARSET=UTF-8" that are appended to the create table definition.
  # * <tt>drop_table(name)</tt>: Drops the table called +name+.
  # * <tt>rename_table(old_name, new_name)</tt>: Renames the table called +old_name+ to +new_name+.
  # * <tt>add_column(table_name, column_name, type, options)</tt>: Adds a new column to the table called +table_name+
  #   named +column_name+ specified to be one of the following types:
  #   :string, :text, :integer, :float, :decimal, :datetime, :timestamp, :time,
  #   :date, :binary, :boolean. A default value can be specified by passing an
  #   +options+ hash like { :default => 11 }. Other options include :limit and :null (e.g. { :limit => 50, :null => false })
  #   -- see ActiveRecord::ConnectionAdapters::TableDefinition#column for details.
  # * <tt>rename_column(table_name, column_name, new_column_name)</tt>: Renames a column but keeps the type and content.
  # * <tt>change_column(table_name, column_name, type, options)</tt>:  Changes the column to a different type using the same
  #   parameters as add_column.
  # * <tt>remove_column(table_name, column_name)</tt>: Removes the column named +column_name+ from the table called +table_name+.
  # * <tt>add_index(table_name, column_names, index_type, index_name)</tt>: Add a new index with the name of the column, or +index_name+ (if specified) on the column(s). Specify an optional +index_type+ (e.g. UNIQUE).
  # * <tt>remove_index(table_name, index_name)</tt>: Remove the index specified by +index_name+.
  #
  # == Irreversible transformations
  #
  # Some transformations are destructive in a manner that cannot be reversed. Migrations of that kind should raise
  # an <tt>IrreversibleMigration</tt> exception in their +down+ method.
  #
  # == Running migrations from within Rails
  #
  # The Rails package has several tools to help create and apply migrations.
  #
  # To generate a new migration, use <tt>script/generate migration MyNewMigration</tt>
  # where MyNewMigration is the name of your migration. The generator will
  # create a file <tt>nnn_my_new_migration.rb</tt> in the <tt>db/migrate/</tt>
  # directory, where <tt>nnn</tt> is the next largest migration number.
  # You may then edit the <tt>self.up</tt> and <tt>self.down</tt> methods of
  # n MyNewMigration.
  #
  # To run migrations against the currently configured database, use
  # <tt>rake migrate</tt>. This will update the database by running all of the
  # pending migrations, creating the <tt>schema_info</tt> table if missing.
  #
  # To roll the database back to a previous migration version, use
  # <tt>rake migrate VERSION=X</tt> where <tt>X</tt> is the version to which
  # you wish to downgrade. If any of the migrations throw an
  # <tt>IrreversibleMigration</tt> exception, that step will fail and you'll
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
  #     def self.up
  #       Tag.find(:all).each { |tag| tag.destroy if tag.pages.empty? }
  #     end
  #
  #     def self.down
  #       # not much we can do to restore deleted data
  #       raise IrreversibleMigration
  #     end
  #   end
  #
  # Others remove columns when they migrate up instead of down:
  #
  #   class RemoveUnnecessaryItemAttributes < ActiveRecord::Migration
  #     def self.up
  #       remove_column :items, :incomplete_items_count
  #       remove_column :items, :completed_items_count
  #     end
  #
  #     def self.down
  #       add_column :items, :incomplete_items_count
  #       add_column :items, :completed_items_count
  #     end
  #   end
  #
  # And sometimes you need to do something in SQL not abstracted directly by migrations:
  #
  #   class MakeJoinUnique < ActiveRecord::Migration
  #     def self.up
  #       execute "ALTER TABLE `pages_linked_pages` ADD UNIQUE `page_id_linked_page_id` (`page_id`,`linked_page_id`)"
  #     end
  #
  #     def self.down
  #       execute "ALTER TABLE `pages_linked_pages` DROP INDEX `page_id_linked_page_id`"
  #     end
  #   end
  #
  # == Using a model after changing its table
  #
  # Sometimes you'll want to add a column in a migration and populate it immediately after. In that case, you'll need
  # to make a call to Base#reset_column_information in order to ensure that the model has the latest column data from
  # after the new column was added. Example:
  #
  #   class AddPeopleSalary < ActiveRecord::Migration
  #     def self.up
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
  # You can also insert your own messages and benchmarks by using the #say_with_time
  # method:
  #
  #   def self.up
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
  class Migration
    @@verbose = true
    cattr_accessor :verbose

    class << self
      def up_with_benchmarks #:nodoc:
        migrate(:up)
      end

      def down_with_benchmarks #:nodoc:
        migrate(:down)
      end

      # Execute this migration in the named direction
      def migrate(direction)
        return unless respond_to?(direction)

        case direction
          when :up   then announce "migrating"
          when :down then announce "reverting"
        end

        result = nil
        time = Benchmark.measure { result = send("#{direction}_without_benchmarks") }

        case direction
          when :up   then announce "migrated (%.4fs)" % time.real; write
          when :down then announce "reverted (%.4fs)" % time.real; write
        end

        result
      end

      # Because the method added may do an alias_method, it can be invoked
      # recursively. We use @ignore_new_methods as a guard to indicate whether
      # it is safe for the call to proceed.
      def singleton_method_added(sym) #:nodoc:
        return if @ignore_new_methods

        begin
          @ignore_new_methods = true

          case sym
            when :up, :down
              klass = (class << self; self; end)
              klass.send(:alias_method_chain, sym, "benchmarks")
          end
        ensure
          @ignore_new_methods = false
        end
      end

      def write(text="")
        puts(text) if verbose
      end

      def announce(message)
        text = "#{@version} #{name}: #{message}"
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
        result
      end

      def suppress_messages
        save, self.verbose = verbose, false
        yield
      ensure
        self.verbose = save
      end

      def method_missing(method, *arguments, &block)
        arg_list = arguments.map(&:inspect) * ', '

        say_with_time "#{method}(#{arg_list})" do
          unless arguments.empty? || method == :execute
            arguments[0] = Migrator.proper_table_name(arguments.first)
          end
          ActiveRecord::Base.connection.send(method, *arguments, &block)
        end
      end
    end
  end

  class Migrator#:nodoc:
    class << self
      def migrate(migrations_path, target_version = nil)
        Base.connection.initialize_schema_information

        case
          when target_version.nil?, current_version < target_version
            up(migrations_path, target_version)
          when current_version > target_version
            down(migrations_path, target_version)
          when current_version == target_version
            return # You're on the right version
        end
      end

      def up(migrations_path, target_version = nil)
        self.new(:up, migrations_path, target_version).migrate
      end

      def down(migrations_path, target_version = nil)
        self.new(:down, migrations_path, target_version).migrate
      end

      def schema_info_table_name
        Base.table_name_prefix + "schema_info" + Base.table_name_suffix
      end

      def current_version
        Base.connection.select_value("SELECT version FROM #{schema_info_table_name}").to_i
      end

      def proper_table_name(name)
        # Use the ActiveRecord objects own table_name, or pre/suffix from ActiveRecord::Base if name is a symbol/string
        name.table_name rescue "#{ActiveRecord::Base.table_name_prefix}#{name}#{ActiveRecord::Base.table_name_suffix}"
      end
    end

    def initialize(direction, migrations_path, target_version = nil)
      raise StandardError.new("This database does not yet support migrations") unless Base.connection.supports_migrations?
      @direction, @migrations_path, @target_version = direction, migrations_path, target_version
      Base.connection.initialize_schema_information
    end

    def current_version
      self.class.current_version
    end

    def migrate
      migration_classes.each do |migration_class|
        Base.logger.info("Reached target version: #{@target_version}") and break if reached_target_version?(migration_class.version)
        next if irrelevant_migration?(migration_class.version)

        Base.logger.info "Migrating to #{migration_class} (#{migration_class.version})"
        migration_class.migrate(@direction)
        set_schema_version(migration_class.version)
      end
    end

    private
      def migration_classes
        migrations = migration_files.inject([]) do |migrations, migration_file|
          load(migration_file)
          version, name = migration_version_and_name(migration_file)
          assert_unique_migration_version(migrations, version.to_i)
          migrations << migration_class(name, version.to_i)
        end

        sorted = migrations.sort_by { |m| m.version }
        down? ? sorted.reverse : sorted
      end

      def assert_unique_migration_version(migrations, version)
        if !migrations.empty? && migrations.find { |m| m.version == version }
          raise DuplicateMigrationVersionError.new(version)
        end
      end

      def migration_files
        files = Dir["#{@migrations_path}/[0-9]*_*.rb"].sort_by do |f|
          migration_version_and_name(f).first.to_i
        end
        down? ? files.reverse : files
      end

      def migration_class(migration_name, version)
        klass = migration_name.camelize.constantize
        class << klass; attr_accessor :version end
        klass.version = version
        klass
      end

      def migration_version_and_name(migration_file)
        return *migration_file.scan(/([0-9]+)_([_a-z0-9]*).rb/).first
      end

      def set_schema_version(version)
        Base.connection.update("UPDATE #{self.class.schema_info_table_name} SET version = #{down? ? version.to_i - 1 : version.to_i}")
      end

      def up?
        @direction == :up
      end

      def down?
        @direction == :down
      end

      def reached_target_version?(version)
        return false if @target_version == nil
        (up? && version.to_i - 1 >= @target_version) || (down? && version.to_i <= @target_version)
      end

      def irrelevant_migration?(version)
        (up? && version.to_i <= current_version) || (down? && version.to_i > current_version)
      end
  end
end
