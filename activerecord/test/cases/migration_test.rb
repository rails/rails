require "cases/helper"
require "cases/migration/helper"
require 'bigdecimal/util'

require 'models/person'
require 'models/topic'
require 'models/developer'
require 'models/computer'

require MIGRATIONS_ROOT + "/valid/2_we_need_reminders"
require MIGRATIONS_ROOT + "/rename/1_we_need_things"
require MIGRATIONS_ROOT + "/rename/2_rename_things"
require MIGRATIONS_ROOT + "/decimal/1_give_me_big_numbers"

class BigNumber < ActiveRecord::Base
  unless current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter)
    attribute :value_of_e, Type::Integer.new
  end
  attribute :my_house_population, Type::Integer.new
end

class Reminder < ActiveRecord::Base; end

class Thing < ActiveRecord::Base; end

class MigrationTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  fixtures :people

  def setup
    super
    %w(reminders people_reminders prefix_reminders_suffix p_things_s).each do |table|
      Reminder.connection.drop_table(table) rescue nil
    end
    Reminder.reset_column_information
    @verbose_was, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false
    ActiveRecord::Base.connection.schema_cache.clear!
  end

  teardown do
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""

    ActiveRecord::Base.connection.initialize_schema_migrations_table
    ActiveRecord::Base.connection.execute "DELETE FROM #{ActiveRecord::Migrator.schema_migrations_table_name}"

    %w(things awesome_things prefix_things_suffix p_awesome_things_s ).each do |table|
      Thing.connection.drop_table(table) rescue nil
    end
    Thing.reset_column_information

    %w(reminders people_reminders prefix_reminders_suffix).each do |table|
      Reminder.connection.drop_table(table) rescue nil
    end
    Reminder.reset_table_name
    Reminder.reset_column_information

    %w(last_name key bio age height wealth birthday favorite_day
       moment_of_truth male administrator funny).each do |column|
      Person.connection.remove_column('people', column) rescue nil
    end
    Person.connection.remove_column("people", "first_name") rescue nil
    Person.connection.remove_column("people", "middle_name") rescue nil
    Person.connection.add_column("people", "first_name", :string)
    Person.reset_column_information

    ActiveRecord::Migration.verbose = @verbose_was
  end

  def test_migrator_versions
    migrations_path = MIGRATIONS_ROOT + "/valid"
    old_path = ActiveRecord::Migrator.migrations_paths
    ActiveRecord::Migrator.migrations_paths = migrations_path

    ActiveRecord::Migrator.up(migrations_path)
    assert_equal 3, ActiveRecord::Migrator.current_version
    assert_equal 3, ActiveRecord::Migrator.last_version
    assert_equal false, ActiveRecord::Migrator.needs_migration?

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid")
    assert_equal 0, ActiveRecord::Migrator.current_version
    assert_equal 3, ActiveRecord::Migrator.last_version
    assert_equal true, ActiveRecord::Migrator.needs_migration?

    ActiveRecord::SchemaMigration.create!(:version => ActiveRecord::Migrator.last_version)
    assert_equal true, ActiveRecord::Migrator.needs_migration?
  ensure
    ActiveRecord::Migrator.migrations_paths = old_path
  end

  def test_migration_detection_without_schema_migration_table
    ActiveRecord::Base.connection.drop_table('schema_migrations') if ActiveRecord::Base.connection.table_exists?('schema_migrations')

    migrations_path = MIGRATIONS_ROOT + "/valid"
    old_path = ActiveRecord::Migrator.migrations_paths
    ActiveRecord::Migrator.migrations_paths = migrations_path

    assert_equal true, ActiveRecord::Migrator.needs_migration?
  ensure
    ActiveRecord::Migrator.migrations_paths = old_path
  end

  def test_any_migrations
    old_path = ActiveRecord::Migrator.migrations_paths
    ActiveRecord::Migrator.migrations_paths = MIGRATIONS_ROOT + "/valid"

    assert ActiveRecord::Migrator.any_migrations?

    ActiveRecord::Migrator.migrations_paths = MIGRATIONS_ROOT + "/empty"

    assert_not ActiveRecord::Migrator.any_migrations?
  ensure
    ActiveRecord::Migrator.migrations_paths = old_path
  end

  def test_migration_version
    ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT + "/version_check", 20131219224947)
  end

  def test_create_table_with_force_true_does_not_drop_nonexisting_table
    if Person.connection.table_exists?(:testings2)
      Person.connection.drop_table :testings2
    end

    # using a copy as we need the drop_table method to
    # continue to work for the ensure block of the test
    temp_conn = Person.connection.dup

    assert_not_equal temp_conn, Person.connection

    temp_conn.create_table :testings2, :force => true do |t|
      t.column :foo, :string
    end
  ensure
    Person.connection.drop_table :testings2 rescue nil
  end

  def connection
    ActiveRecord::Base.connection
  end

  def test_migration_instance_has_connection
    migration = Class.new(ActiveRecord::Migration).new
    assert_equal connection, migration.connection
  end

  def test_method_missing_delegates_to_connection
    migration = Class.new(ActiveRecord::Migration) {
      def connection
        Class.new {
          def create_table; "hi mom!"; end
        }.new
      end
    }.new

    assert_equal "hi mom!", migration.method_missing(:create_table)
  end

  def test_add_table_with_decimals
    Person.connection.drop_table :big_numbers rescue nil

    assert !BigNumber.table_exists?
    GiveMeBigNumbers.up

    assert BigNumber.create(
      :bank_balance => 1586.43,
      :big_bank_balance => BigDecimal("1000234000567.95"),
      :world_population => 6000000000,
      :my_house_population => 3,
      :value_of_e => BigDecimal("2.7182818284590452353602875")
    )

    b = BigNumber.first
    assert_not_nil b

    assert_not_nil b.bank_balance
    assert_not_nil b.big_bank_balance
    assert_not_nil b.world_population
    assert_not_nil b.my_house_population
    assert_not_nil b.value_of_e

    # TODO: set world_population >= 2**62 to cover 64-bit platforms and test
    # is_a?(Bignum)
    assert_kind_of Integer, b.world_population
    assert_equal 6000000000, b.world_population
    assert_kind_of Fixnum, b.my_house_population
    assert_equal 3, b.my_house_population
    assert_kind_of BigDecimal, b.bank_balance
    assert_equal BigDecimal("1586.43"), b.bank_balance
    assert_kind_of BigDecimal, b.big_bank_balance
    assert_equal BigDecimal("1000234000567.95"), b.big_bank_balance

    # This one is fun. The 'value_of_e' field is defined as 'DECIMAL' with
    # precision/scale explicitly left out.  By the SQL standard, numbers
    # assigned to this field should be truncated but that's seldom respected.
    if current_adapter?(:PostgreSQLAdapter)
      # - PostgreSQL changes the SQL spec on columns declared simply as
      # "decimal" to something more useful: instead of being given a scale
      # of 0, they take on the compile-time limit for precision and scale,
      # so the following should succeed unless you have used really wacky
      # compilation options
      # - SQLite2 has the default behavior of preserving all data sent in,
      # so this happens there too
      assert_kind_of BigDecimal, b.value_of_e
      assert_equal BigDecimal("2.7182818284590452353602875"), b.value_of_e
    elsif current_adapter?(:SQLite3Adapter)
      # - SQLite3 stores a float, in violation of SQL
      assert_kind_of BigDecimal, b.value_of_e
      assert_in_delta BigDecimal("2.71828182845905"), b.value_of_e, 0.00000000000001
    else
      # - SQL standard is an integer
      assert_kind_of Fixnum, b.value_of_e
      assert_equal 2, b.value_of_e
    end

    GiveMeBigNumbers.down
    assert_raise(ActiveRecord::StatementInvalid) { BigNumber.first }
  end

  def test_filtering_migrations
    assert_no_column Person, :last_name
    assert !Reminder.table_exists?

    name_filter = lambda { |migration| migration.name == "ValidPeopleHaveLastNames" }
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", &name_filter)

    assert_column Person, :last_name
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", &name_filter)

    assert_no_column Person, :last_name
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }
  end

  class MockMigration < ActiveRecord::Migration
    attr_reader :went_up, :went_down
    def initialize
      @went_up   = false
      @went_down = false
    end

    def up
      @went_up = true
      super
    end

    def down
      @went_down = true
      super
    end
  end

  def test_instance_based_migration_up
    migration = MockMigration.new
    assert !migration.went_up, 'have not gone up'
    assert !migration.went_down, 'have not gone down'

    migration.migrate :up
    assert migration.went_up, 'have gone up'
    assert !migration.went_down, 'have not gone down'
  end

  def test_instance_based_migration_down
    migration = MockMigration.new
    assert !migration.went_up, 'have not gone up'
    assert !migration.went_down, 'have not gone down'

    migration.migrate :down
    assert !migration.went_up, 'have gone up'
    assert migration.went_down, 'have not gone down'
  end

  if ActiveRecord::Base.connection.supports_ddl_transactions?
    def test_migrator_one_up_with_exception_and_rollback
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise 'Something broke'
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], 100)

      e = assert_raise(StandardError) { migrator.migrate }

      assert_equal "An error has occurred, this and all later migrations canceled:\n\nSomething broke", e.message

      assert_no_column Person, :last_name,
        "On error, the Migrator should revert schema changes but it did not."
    end

    def test_migrator_one_up_with_exception_and_rollback_using_run
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration) {
        def version; 100 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise 'Something broke'
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], 100)

      e = assert_raise(StandardError) { migrator.run }

      assert_equal "An error has occurred, this migration was canceled:\n\nSomething broke", e.message

      assert_no_column Person, :last_name,
        "On error, the Migrator should revert schema changes but it did not."
    end

    def test_migration_without_transaction
      assert_no_column Person, :last_name

      migration = Class.new(ActiveRecord::Migration) {
        self.disable_ddl_transaction!

        def version; 101 end
        def migrate(x)
          add_column "people", "last_name", :string
          raise 'Something broke'
        end
      }.new

      migrator = ActiveRecord::Migrator.new(:up, [migration], 101)
      e = assert_raise(StandardError) { migrator.migrate }
      assert_equal "An error has occurred, all later migrations canceled:\n\nSomething broke", e.message

      assert_column Person, :last_name,
        "without ddl transactions, the Migrator should not rollback on error but it did."
    ensure
      Person.reset_column_information
      if Person.column_names.include?('last_name')
        Person.connection.remove_column('people', 'last_name')
      end
    end
  end

  def test_schema_migrations_table_name
    original_schema_migrations_table_name = ActiveRecord::Migrator.schema_migrations_table_name

    assert_equal "schema_migrations", ActiveRecord::Migrator.schema_migrations_table_name
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    Reminder.reset_table_name
    assert_equal "prefix_schema_migrations_suffix", ActiveRecord::Migrator.schema_migrations_table_name
    ActiveRecord::Base.schema_migrations_table_name = "changed"
    Reminder.reset_table_name
    assert_equal "prefix_changed_suffix", ActiveRecord::Migrator.schema_migrations_table_name
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    Reminder.reset_table_name
    assert_equal "changed", ActiveRecord::Migrator.schema_migrations_table_name
  ensure
    ActiveRecord::Base.schema_migrations_table_name = original_schema_migrations_table_name
    Reminder.reset_table_name
  end

  def test_proper_table_name_on_migration
    reminder_class = new_isolated_reminder_class
    migration = ActiveRecord::Migration.new
    assert_equal "table", migration.proper_table_name('table')
    assert_equal "table", migration.proper_table_name(:table)
    assert_equal "reminders", migration.proper_table_name(reminder_class)
    reminder_class.reset_table_name
    assert_equal reminder_class.table_name, migration.proper_table_name(reminder_class)

    # Use the model's own prefix/suffix if a model is given
    ActiveRecord::Base.table_name_prefix = "ARprefix_"
    ActiveRecord::Base.table_name_suffix = "_ARsuffix"
    reminder_class.table_name_prefix = 'prefix_'
    reminder_class.table_name_suffix = '_suffix'
    reminder_class.reset_table_name
    assert_equal "prefix_reminders_suffix", migration.proper_table_name(reminder_class)
    reminder_class.table_name_prefix = ''
    reminder_class.table_name_suffix = ''
    reminder_class.reset_table_name

    # Use AR::Base's prefix/suffix if string or symbol is given
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    reminder_class.reset_table_name
    assert_equal "prefix_table_suffix", migration.proper_table_name('table', migration.table_name_options)
    assert_equal "prefix_table_suffix", migration.proper_table_name(:table, migration.table_name_options)
  end

  def test_rename_table_with_prefix_and_suffix
    assert !Thing.table_exists?
    ActiveRecord::Base.table_name_prefix = 'p_'
    ActiveRecord::Base.table_name_suffix = '_s'
    Thing.reset_table_name
    Thing.reset_sequence_name
    WeNeedThings.up

    assert Thing.create("content" => "hello world")
    assert_equal "hello world", Thing.first.content

    RenameThings.up
    Thing.table_name = "p_awesome_things_s"

    assert_equal "hello world", Thing.first.content
  ensure
    Thing.reset_table_name
    Thing.reset_sequence_name
  end

  def test_add_drop_table_with_prefix_and_suffix
    assert !Reminder.table_exists?
    ActiveRecord::Base.table_name_prefix = 'prefix_'
    ActiveRecord::Base.table_name_suffix = '_suffix'
    Reminder.reset_table_name
    Reminder.reset_sequence_name
    WeNeedReminders.up
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.first.content

    WeNeedReminders.down
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.first }
  ensure
    Reminder.reset_sequence_name
  end

  def test_create_table_with_binary_column
    Person.connection.drop_table :binary_testings rescue nil

    assert_nothing_raised {
      Person.connection.create_table :binary_testings do |t|
        t.column "data", :binary, :null => false
      end
    }

    columns = Person.connection.columns(:binary_testings)
    data_column = columns.detect { |c| c.name == "data" }

    assert_nil data_column.default

    Person.connection.drop_table :binary_testings rescue nil
  end

  unless mysql_enforcing_gtid_consistency?
    def test_create_table_with_query
      Person.connection.drop_table :table_from_query_testings rescue nil
      Person.connection.create_table(:person, force: true)

      Person.connection.create_table :table_from_query_testings, as: "SELECT id FROM person"

      columns = Person.connection.columns(:table_from_query_testings)
      assert_equal 1, columns.length
      assert_equal "id", columns.first.name

      Person.connection.drop_table :table_from_query_testings rescue nil
    end

    def test_create_table_with_query_from_relation
      Person.connection.drop_table :table_from_query_testings rescue nil
      Person.connection.create_table(:person, force: true)

      Person.connection.create_table :table_from_query_testings, as: Person.select(:id)

      columns = Person.connection.columns(:table_from_query_testings)
      assert_equal 1, columns.length
      assert_equal "id", columns.first.name

      Person.connection.drop_table :table_from_query_testings rescue nil
    end
  end

  if current_adapter? :OracleAdapter
    def test_create_table_with_custom_sequence_name
      # table name is 29 chars, the standard sequence name will
      # be 33 chars and should be shortened
      assert_nothing_raised do
        begin
          Person.connection.create_table :table_with_name_thats_just_ok do |t|
            t.column :foo, :string, :null => false
          end
        ensure
          Person.connection.drop_table :table_with_name_thats_just_ok rescue nil
        end
      end

      # should be all good w/ a custom sequence name
      assert_nothing_raised do
        begin
          Person.connection.create_table :table_with_name_thats_just_ok,
            :sequence_name => 'suitably_short_seq' do |t|
            t.column :foo, :string, :null => false
          end

          Person.connection.execute("select suitably_short_seq.nextval from dual")

        ensure
          Person.connection.drop_table :table_with_name_thats_just_ok,
            :sequence_name => 'suitably_short_seq' rescue nil
        end
      end

      # confirm the custom sequence got dropped
      assert_raise(ActiveRecord::StatementInvalid) do
        Person.connection.execute("select suitably_short_seq.nextval from dual")
      end
    end
  end

  if current_adapter?(:MysqlAdapter, :Mysql2Adapter, :PostgreSQLAdapter)
    def test_out_of_range_limit_should_raise
      Person.connection.drop_table :test_limits rescue nil
      assert_raise(ActiveRecord::ActiveRecordError, "integer limit didn't raise") do
        Person.connection.create_table :test_integer_limits, :force => true do |t|
          t.column :bigone, :integer, :limit => 10
        end
      end

      unless current_adapter?(:PostgreSQLAdapter)
        assert_raise(ActiveRecord::ActiveRecordError, "text limit didn't raise") do
          Person.connection.create_table :test_text_limits, :force => true do |t|
            t.column :bigtext, :text, :limit => 0xfffffffff
          end
        end
      end

      Person.connection.drop_table :test_limits rescue nil
    end
  end

  protected
    # This is needed to isolate class_attribute assignments like `table_name_prefix`
    # for each test case.
    def new_isolated_reminder_class
      Class.new(Reminder) {
        def self.name; "Reminder"; end
        def self.base_class; self; end
      }
    end
end

class ReservedWordsMigrationTest < ActiveRecord::TestCase
  def test_drop_index_from_table_named_values
    connection = Person.connection
    connection.create_table :values, :force => true do |t|
      t.integer :value
    end

    assert_nothing_raised do
      connection.add_index :values, :value
      connection.remove_index :values, :column => :value
    end

    connection.drop_table :values rescue nil
  end
end

class ExplicitlyNamedIndexMigrationTest < ActiveRecord::TestCase
  def test_drop_index_by_name
    connection = Person.connection
    connection.create_table :values, force: true do |t|
      t.integer :value
    end

    assert_nothing_raised ArgumentError do
      connection.add_index :values, :value, name: 'a_different_name'
      connection.remove_index :values, column: :value, name: 'a_different_name'
    end

    connection.drop_table :values rescue nil
  end
end

if ActiveRecord::Base.connection.supports_bulk_alter?
  class BulkAlterTableMigrationsTest < ActiveRecord::TestCase
    def setup
      @connection = Person.connection
      @connection.create_table(:delete_me, :force => true) {|t| }
      Person.reset_column_information
      Person.reset_sequence_name
    end

    teardown do
      Person.connection.drop_table(:delete_me) rescue nil
    end

    def test_adding_multiple_columns
      assert_queries(1) do
        with_bulk_change_table do |t|
          t.column :name, :string
          t.string :qualification, :experience
          t.integer :age, :default => 0
          t.date :birthdate
          t.timestamps null: true
        end
      end

      assert_equal 8, columns.size
      [:name, :qualification, :experience].each {|s| assert_equal :string, column(s).type }
      assert_equal '0', column(:age).default
    end

    def test_removing_columns
      with_bulk_change_table do |t|
        t.string :qualification, :experience
      end

      [:qualification, :experience].each {|c| assert column(c) }

      assert_queries(1) do
        with_bulk_change_table do |t|
          t.remove :qualification, :experience
          t.string :qualification_experience
        end
      end

      [:qualification, :experience].each {|c| assert ! column(c) }
      assert column(:qualification_experience)
    end

    def test_adding_indexes
      with_bulk_change_table do |t|
        t.string :username
        t.string :name
        t.integer :age
      end

      # Adding an index fires a query every time to check if an index already exists or not
      assert_queries(3) do
        with_bulk_change_table do |t|
          t.index :username, :unique => true, :name => :awesome_username_index
          t.index [:name, :age]
        end
      end

      assert_equal 2, indexes.size

      name_age_index = index(:index_delete_me_on_name_and_age)
      assert_equal ['name', 'age'].sort, name_age_index.columns.sort
      assert ! name_age_index.unique

      assert index(:awesome_username_index).unique
    end

    def test_removing_index
      with_bulk_change_table do |t|
        t.string :name
        t.index :name
      end

      assert index(:index_delete_me_on_name)

      assert_queries(3) do
        with_bulk_change_table do |t|
          t.remove_index :name
          t.index :name, :name => :new_name_index, :unique => true
        end
      end

      assert ! index(:index_delete_me_on_name)

      new_name_index = index(:new_name_index)
      assert new_name_index.unique
    end

    def test_changing_columns
      with_bulk_change_table do |t|
        t.string :name
        t.date :birthdate
      end

      assert ! column(:name).default
      assert_equal :date, column(:birthdate).type

      # One query for columns (delete_me table)
      # One query for primary key (delete_me table)
      # One query to do the bulk change
      assert_queries(3, :ignore_none => true) do
        with_bulk_change_table do |t|
          t.change :name, :string, :default => 'NONAME'
          t.change :birthdate, :datetime
        end
      end

      assert_equal 'NONAME', column(:name).default
      assert_equal :datetime, column(:birthdate).type
    end

    protected

    def with_bulk_change_table
      # Reset columns/indexes cache as we're changing the table
      @columns = @indexes = nil

      Person.connection.change_table(:delete_me, :bulk => true) do |t|
        yield t
      end
    end

    def column(name)
      columns.detect {|c| c.name == name.to_s }
    end

    def columns
      @columns ||= Person.connection.columns('delete_me')
    end

    def index(name)
      indexes.detect {|i| i.name == name.to_s }
    end

    def indexes
      @indexes ||= Person.connection.indexes('delete_me')
    end
  end # AlterTableMigrationsTest

end

class CopyMigrationsTest < ActiveRecord::TestCase
  def setup
  end

  def clear
    ActiveRecord::Base.timestamped_migrations = true
    to_delete = Dir[@migrations_path + "/*.rb"] - @existing_migrations
    File.delete(*to_delete)
  end

  def test_copying_migrations_without_timestamps
    ActiveRecord::Base.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy"})
    assert File.exist?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exist?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
    assert_equal [@migrations_path + "/4_people_have_hobbies.bukkits.rb", @migrations_path + "/5_people_have_descriptions.bukkits.rb"], copied.map(&:filename)

    expected = "# This migration comes from bukkits (originally 1)"
    assert_equal expected, IO.readlines(@migrations_path + "/4_people_have_hobbies.bukkits.rb")[0].chomp

    files_count = Dir[@migrations_path + "/*.rb"].length
    copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy"})
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    assert copied.empty?
  ensure
    clear
  end

  def test_copying_migrations_without_timestamps_from_2_sources
    ActiveRecord::Base.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy"
    sources[:omg] = MIGRATIONS_ROOT + "/to_copy2"
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert File.exist?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exist?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
    assert File.exist?(@migrations_path + "/6_create_articles.omg.rb")
    assert File.exist?(@migrations_path + "/7_create_comments.omg.rb")

    files_count = Dir[@migrations_path + "/*.rb"].length
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      expected = [@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb",
                  @migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb"]
      assert_equal expected, copied.map(&:filename)

      files_count = Dir[@migrations_path + "/*.rb"].length
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
      assert copied.empty?
    end
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps_from_2_sources
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"
    sources[:omg]     = MIGRATIONS_ROOT + "/to_copy_with_timestamps2"

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, sources)
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101012_create_articles.omg.rb")
      assert File.exist?(@migrations_path + "/20100726101013_create_comments.omg.rb")
      assert_equal 4, copied.length

      files_count = Dir[@migrations_path + "/*.rb"].length
      ActiveRecord::Migration.copy(@migrations_path, sources)
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    end
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps_to_destination_with_timestamps_in_future
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    travel_to(Time.utc(2010, 2, 20, 10, 10, 10)) do
      ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exist?(@migrations_path + "/20100301010102_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100301010103_people_have_descriptions.bukkits.rb")

      files_count = Dir[@migrations_path + "/*.rb"].length
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
      assert copied.empty?
    end
  ensure
    clear
  end

  def test_copying_migrations_preserving_magic_comments
    ActiveRecord::Base.timestamped_migrations = false
    @migrations_path = MIGRATIONS_ROOT + "/valid"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/magic"})
    assert File.exist?(@migrations_path + "/4_currencies_have_symbols.bukkits.rb")
    assert_equal [@migrations_path + "/4_currencies_have_symbols.bukkits.rb"], copied.map(&:filename)

    expected = "# coding: ISO-8859-15\n# This migration comes from bukkits (originally 1)"
    assert_equal expected, IO.readlines(@migrations_path + "/4_currencies_have_symbols.bukkits.rb")[0..1].join.chomp

    files_count = Dir[@migrations_path + "/*.rb"].length
    copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/magic"})
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
    assert copied.empty?
  ensure
    clear
  end

  def test_skipping_migrations
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"
    sources[:omg]     = MIGRATIONS_ROOT + "/to_copy_with_name_collision"

    skipped = []
    on_skip = Proc.new { |name, migration| skipped << "#{name} #{migration.name}" }
    copied = ActiveRecord::Migration.copy(@migrations_path, sources, :on_skip => on_skip)
    assert_equal 2, copied.length

    assert_equal 1, skipped.length
    assert_equal ["omg PeopleHaveHobbies"], skipped
  ensure
    clear
  end

  def test_skip_is_not_called_if_migrations_are_from_the_same_plugin
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = {}
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"

    skipped = []
    on_skip = Proc.new { |name, migration| skipped << "#{name} #{migration.name}" }
    copied = ActiveRecord::Migration.copy(@migrations_path, sources, :on_skip => on_skip)
    ActiveRecord::Migration.copy(@migrations_path, sources, :on_skip => on_skip)

    assert_equal 2, copied.length
    assert_equal 0, skipped.length
  ensure
    clear
  end

  def test_copying_migrations_to_non_existing_directory
    @migrations_path = MIGRATIONS_ROOT + "/non_existing"
    @existing_migrations = []

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
    Dir.delete(@migrations_path)
  end

  def test_copying_migrations_to_empty_directory
    @migrations_path = MIGRATIONS_ROOT + "/empty"
    @existing_migrations = []

    travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exist?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exist?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
  end

  def test_check_pending_with_stdlib_logger
    old, ActiveRecord::Base.logger = ActiveRecord::Base.logger, ::Logger.new($stdout)
    quietly do
      assert_nothing_raised { ActiveRecord::Migration::CheckPending.new(Proc.new {}).call({}) }
    end
  ensure
    ActiveRecord::Base.logger = old
  end

  private

  def quietly
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        yield
      end
    end
  end

  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
    old_stream.close
  end
end
