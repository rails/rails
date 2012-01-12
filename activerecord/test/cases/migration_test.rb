require "cases/helper"
require 'bigdecimal/util'

require 'models/person'
require 'models/topic'
require 'models/developer'

require MIGRATIONS_ROOT + "/valid/2_we_need_reminders"
require MIGRATIONS_ROOT + "/rename/1_we_need_things"
require MIGRATIONS_ROOT + "/rename/2_rename_things"
require MIGRATIONS_ROOT + "/decimal/1_give_me_big_numbers"

class BigNumber < ActiveRecord::Base; end

class Reminder < ActiveRecord::Base; end

class Thing < ActiveRecord::Base; end

class ActiveRecord::Migration
  class << self
    attr_accessor :message_count
  end

  def puts(text="")
    ActiveRecord::Migration.message_count ||= 0
    ActiveRecord::Migration.message_count += 1
  end
end

module ActiveRecord
  class MigrationTest < ActiveRecord::TestCase
    attr_reader :connection

    def setup
      super
      @connection = Base.connection
    end
  end
end

class MigrationTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  fixtures :people

  def setup
    super
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migration.message_count = 0
  end

  def teardown
    ActiveRecord::Base.connection.initialize_schema_migrations_table
    ActiveRecord::Base.connection.execute "DELETE FROM #{ActiveRecord::Migrator.schema_migrations_table_name}"

    %w(things awesome_things prefix_things_suffix prefix_awesome_things_suffix).each do |table|
      Thing.connection.drop_table(table) rescue nil
    end
    Thing.reset_column_information

    %w(reminders people_reminders prefix_reminders_suffix).each do |table|
      Reminder.connection.drop_table(table) rescue nil
    end
    Reminder.reset_column_information

    %w(last_name key bio age height wealth birthday favorite_day
       moment_of_truth male administrator funny).each do |column|
      Person.connection.remove_column('people', column) rescue nil
    end
    Person.connection.remove_column("people", "first_name") rescue nil
    Person.connection.remove_column("people", "middle_name") rescue nil
    Person.connection.add_column("people", "first_name", :string, :limit => 40)
    Person.reset_column_information
  end

  def test_create_table_with_force_true_does_not_drop_nonexisting_table
    if Person.connection.table_exists?(:testings2)
      Person.connection.drop_table :testings2
    end

    # using a copy as we need the drop_table method to
    # continue to work for the ensure block of the test
    temp_conn = Person.connection.dup
    temp_conn.extend(Module.new {
      def drop_table; raise "no"; end
    })
    temp_conn.create_table :testings2, :force => true do |t|
      t.column :foo, :string
    end
  ensure
    Person.connection.drop_table :testings2 rescue nil
  end

  def test_rename_column_preserves_default_value_not_null
    begin
      default_before = Developer.connection.columns("developers").find { |c| c.name == "salary" }.default
      assert_equal 70000, default_before
      Developer.connection.rename_column "developers", "salary", "anual_salary"
      Developer.reset_column_information
      assert Developer.column_names.include?("anual_salary")
      default_after = Developer.connection.columns("developers").find { |c| c.name == "anual_salary" }.default
      assert_equal 70000, default_after
    ensure
      Developer.connection.rename_column "developers", "anual_salary", "salary"
      Developer.reset_column_information
    end
  end

  def test_rename_nonexistent_column
    ActiveRecord::Base.connection.create_table(:hats) do |table|
      table.column :hat_name, :string, :default => nil
    end
    exception = if current_adapter?(:PostgreSQLAdapter, :OracleAdapter)
      ActiveRecord::StatementInvalid
    else
      ActiveRecord::ActiveRecordError
    end
    assert_raise(exception) do
      Person.connection.rename_column "hats", "nonexistent", "should_fail"
    end
  ensure
    ActiveRecord::Base.connection.drop_table(:hats)
  end

  def test_rename_column_with_sql_reserved_word
    begin
      assert_nothing_raised { Person.connection.rename_column "people", "first_name", "group" }
      Person.reset_column_information
      assert Person.column_names.include?("group")
    ensure
      Person.connection.remove_column("people", "group") rescue nil
      Person.connection.add_column("people", "first_name", :string) rescue nil
    end
  end

  def test_rename_column_with_an_index
    ActiveRecord::Base.connection.create_table(:hats) do |table|
      table.column :hat_name, :string, :limit => 100
      table.column :hat_size, :integer
    end
    Person.connection.add_index :hats, :hat_name
    assert_nothing_raised do
      Person.connection.rename_column "hats", "hat_name", "name"
    end
  ensure
    ActiveRecord::Base.connection.drop_table(:hats)
  end

  def test_remove_column_with_index
    ActiveRecord::Base.connection.create_table(:hats) do |table|
      table.column :hat_name, :string, :limit => 100
      table.column :hat_size, :integer
    end
    ActiveRecord::Base.connection.add_index "hats", "hat_size"

    assert_nothing_raised { Person.connection.remove_column("hats", "hat_size") }
  ensure
    ActiveRecord::Base.connection.drop_table(:hats)
  end

  def test_remove_column_with_multi_column_index
    ActiveRecord::Base.connection.create_table(:hats) do |table|
      table.column :hat_name, :string, :limit => 100
      table.column :hat_size, :integer
      table.column :hat_style, :string, :limit => 100
    end
    ActiveRecord::Base.connection.add_index "hats", ["hat_style", "hat_size"], :unique => true

    assert_nothing_raised { Person.connection.remove_column("hats", "hat_size") }
  ensure
    ActiveRecord::Base.connection.drop_table(:hats)
  end

  def test_remove_column_no_second_parameter_raises_exception
    assert_raise(ArgumentError) { Person.connection.remove_column("funny") }
  end

  def test_change_type_of_not_null_column
    assert_nothing_raised do
      Topic.connection.change_column "topics", "written_on", :datetime, :null => false
      Topic.reset_column_information

      Topic.connection.change_column "topics", "written_on", :datetime, :null => false
      Topic.reset_column_information

      Topic.connection.change_column "topics", "written_on", :datetime, :null => true
      Topic.reset_column_information
    end
  end

  def test_rename_table_for_sqlite_should_work_with_reserved_words
    skip "not supported" unless current_adapter?(:SQLite3Adapter)

    begin
      assert_nothing_raised do
        ActiveRecord::Base.connection.rename_table :references, :old_references
        ActiveRecord::Base.connection.create_table :octopuses do |t|
          t.column :url, :string
        end
      end

      assert_nothing_raised { ActiveRecord::Base.connection.rename_table :octopuses, :references }

      # Using explicit id in insert for compatibility across all databases
      con = ActiveRecord::Base.connection
      assert_nothing_raised do
        con.execute "INSERT INTO 'references' (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://rubyonrails.com')"
      end
      assert_equal 'http://rubyonrails.com', ActiveRecord::Base.connection.select_value("SELECT url FROM 'references' WHERE id=1")

    ensure
      ActiveRecord::Base.connection.drop_table :references
      ActiveRecord::Base.connection.rename_table :old_references, :references
    end
  end

  def test_rename_table
    begin
      ActiveRecord::Base.connection.create_table :octopuses do |t|
        t.column :url, :string
      end
      ActiveRecord::Base.connection.rename_table :octopuses, :octopi

      # Using explicit id in insert for compatibility across all databases
      con = ActiveRecord::Base.connection
      con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)
      assert_nothing_raised { con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')" }
      con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

      assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', ActiveRecord::Base.connection.select_value("SELECT url FROM octopi WHERE id=1")

    ensure
      ActiveRecord::Base.connection.drop_table :octopuses rescue nil
      ActiveRecord::Base.connection.drop_table :octopi rescue nil
    end
  end

  def test_change_column_nullability
    Person.delete_all
    Person.connection.add_column "people", "funny", :boolean
    Person.reset_column_information
    assert Person.columns_hash["funny"].null, "Column 'funny' must initially allow nulls"
    Person.connection.change_column "people", "funny", :boolean, :null => false, :default => true
    Person.reset_column_information
    assert !Person.columns_hash["funny"].null, "Column 'funny' must *not* allow nulls at this point"
    Person.connection.change_column "people", "funny", :boolean, :null => true
    Person.reset_column_information
    assert Person.columns_hash["funny"].null, "Column 'funny' must allow nulls again at this point"
  end

  def test_rename_table_with_an_index
    begin
      ActiveRecord::Base.connection.create_table :octopuses do |t|
        t.column :url, :string
      end
      ActiveRecord::Base.connection.add_index :octopuses, :url

      ActiveRecord::Base.connection.rename_table :octopuses, :octopi

      # Using explicit id in insert for compatibility across all databases
      con = ActiveRecord::Base.connection
      con.enable_identity_insert("octopi", true) if current_adapter?(:SybaseAdapter)
      assert_nothing_raised { con.execute "INSERT INTO octopi (#{con.quote_column_name('id')}, #{con.quote_column_name('url')}) VALUES (1, 'http://www.foreverflying.com/octopus-black7.jpg')" }
      con.enable_identity_insert("octopi", false) if current_adapter?(:SybaseAdapter)

      assert_equal 'http://www.foreverflying.com/octopus-black7.jpg', ActiveRecord::Base.connection.select_value("SELECT url FROM octopi WHERE id=1")
      assert ActiveRecord::Base.connection.indexes(:octopi).first.columns.include?("url")
    ensure
      ActiveRecord::Base.connection.drop_table :octopuses rescue nil
      ActiveRecord::Base.connection.drop_table :octopi rescue nil
    end
  end

  def test_change_column
    Person.connection.add_column 'people', 'age', :integer
    label = "test_change_column Columns"
    old_columns = Person.connection.columns(Person.table_name, label)
    assert old_columns.find { |c| c.name == 'age' and c.type == :integer }

    assert_nothing_raised { Person.connection.change_column "people", "age", :string }

    new_columns = Person.connection.columns(Person.table_name, label)
    assert_nil new_columns.find { |c| c.name == 'age' and c.type == :integer }
    assert new_columns.find { |c| c.name == 'age' and c.type == :string }

    old_columns = Topic.connection.columns(Topic.table_name, label)
    assert old_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == true }
    assert_nothing_raised { Topic.connection.change_column :topics, :approved, :boolean, :default => false }
    new_columns = Topic.connection.columns(Topic.table_name, label)
    assert_nil new_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == true }
    assert new_columns.find { |c| c.name == 'approved' and c.type == :boolean and c.default == false }
    assert_nothing_raised { Topic.connection.change_column :topics, :approved, :boolean, :default => true }
  end

  def test_change_column_with_nil_default
    Person.connection.add_column "people", "contributor", :boolean, :default => true
    Person.reset_column_information
    assert Person.new.contributor?

    assert_nothing_raised { Person.connection.change_column "people", "contributor", :boolean, :default => nil }
    Person.reset_column_information
    assert !Person.new.contributor?
    assert_nil Person.new.contributor
  ensure
    Person.connection.remove_column("people", "contributor") rescue nil
  end

  def test_change_column_with_new_default
    Person.connection.add_column "people", "administrator", :boolean, :default => true
    Person.reset_column_information
    assert Person.new.administrator?

    assert_nothing_raised { Person.connection.change_column "people", "administrator", :boolean, :default => false }
    Person.reset_column_information
    assert !Person.new.administrator?
  ensure
    Person.connection.remove_column("people", "administrator") rescue nil
  end

  def test_change_column_default
    Person.connection.change_column_default "people", "first_name", "Tester"
    Person.reset_column_information
    assert_equal "Tester", Person.new.first_name
  end

  def test_change_column_default_to_null
    Person.connection.change_column_default "people", "first_name", nil
    Person.reset_column_information
    assert_nil Person.new.first_name
  end

  def test_add_table
    assert !Reminder.table_exists?

    WeNeedReminders.up

    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.find(:first).content

    WeNeedReminders.down
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
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

    b = BigNumber.find(:first)
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
    assert_raise(ActiveRecord::StatementInvalid) { BigNumber.find(:first) }
  end

  def test_migrator
    assert !Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?

    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid")

    assert_equal 3, ActiveRecord::Migrator.current_version
    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.find(:first).content

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid")

    assert_equal 0, ActiveRecord::Migrator.current_version
    Person.reset_column_information
    assert !Person.column_methods_hash.include?(:last_name)
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
  end

  def test_filtering_migrations
    assert !Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?

    name_filter = lambda { |migration| migration.name == "ValidPeopleHaveLastNames" }
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", &name_filter)

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.find(:first) }

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", &name_filter)

    Person.reset_column_information
    assert !Person.column_methods_hash.include?(:last_name)
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
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

  def test_migrator_one_up
    assert !Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?

    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?

    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 2)

    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.find(:first).content
  end

  def test_migrator_one_down
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid")

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", 1)

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?
  end

  def test_migrator_one_up_one_down
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)
    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", 0)

    assert !Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?
  end

  def test_migrator_double_up
    assert_equal(0, ActiveRecord::Migrator.current_version)
    ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT + "/valid", 1)
    assert_nothing_raised { ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT + "/valid", 1) }
    assert_equal(1, ActiveRecord::Migrator.current_version)
  end

  def test_migrator_double_down
    assert_equal(0, ActiveRecord::Migrator.current_version)
    ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT + "/valid", 1)
    ActiveRecord::Migrator.run(:down, MIGRATIONS_ROOT + "/valid", 1)
    assert_nothing_raised { ActiveRecord::Migrator.run(:down, MIGRATIONS_ROOT + "/valid", 1) }
    assert_equal(0, ActiveRecord::Migrator.current_version)
  end

  def test_migrator_one_up_with_exception_and_rollback
    unless ActiveRecord::Base.connection.supports_ddl_transactions?
      skip "not supported on #{ActiveRecord::Base.connection.class}"
    end

    refute Person.column_methods_hash.include?(:last_name)

    migration = Struct.new(:name, :version) {
      def migrate(x); raise 'Something broke'; end
    }.new('zomg', 100)

    migrator = ActiveRecord::Migrator.new(:up, [migration], 100)

    e = assert_raise(StandardError) { migrator.migrate }

    assert_equal "An error has occurred, this and all later migrations canceled:\n\nSomething broke", e.message

    Person.reset_column_information
    refute Person.column_methods_hash.include?(:last_name)
  end

  def test_finds_migrations
    list = ActiveRecord::Migrator.migrations(MIGRATIONS_ROOT + "/valid")
    migrations = ActiveRecord::Migrator.new(:up, list).migrations

    [[1, 'ValidPeopleHaveLastNames'], [2, 'WeNeedReminders'], [3, 'InnocentJointable']].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_in_subdirectories
    list = ActiveRecord::Migrator.migrations(MIGRATIONS_ROOT + "/valid_with_subdirectories")
    migrations = ActiveRecord::Migrator.new(:up, list).migrations

    [[1, 'ValidPeopleHaveLastNames'], [2, 'WeNeedReminders'], [3, 'InnocentJointable']].each_with_index do |pair, i|
      assert_equal migrations[i].version, pair.first
      assert_equal migrations[i].name, pair.last
    end
  end

  def test_finds_migrations_from_two_directories
    directories = [MIGRATIONS_ROOT + '/valid_with_timestamps', MIGRATIONS_ROOT + '/to_copy_with_timestamps']
    list = ActiveRecord::Migrator.migrations directories
    migrations = ActiveRecord::Migrator.new(:up, list).migrations

    [[20090101010101, "PeopleHaveHobbies"],
     [20090101010202, "PeopleHaveDescriptions"],
     [20100101010101, "ValidWithTimestampsPeopleHaveLastNames"],
     [20100201010101, "ValidWithTimestampsWeNeedReminders"],
     [20100301010101, "ValidWithTimestampsInnocentJointable"]].each_with_index do |pair, i|
      assert_equal pair.first, migrations[i].version
      assert_equal pair.last, migrations[i].name
    end
  end

  def test_dump_schema_information_outputs_lexically_ordered_versions
    migration_path = MIGRATIONS_ROOT + '/valid_with_timestamps'
    ActiveRecord::Migrator.run(:up, migration_path, 20100301010101)
    ActiveRecord::Migrator.run(:up, migration_path, 20100201010101)

    schema_info = ActiveRecord::Base.connection.dump_schema_information
    assert_match(/20100201010101.*20100301010101/m, schema_info)
  end

  def test_finds_pending_migrations
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/interleaved/pass_2", 1)
    migration_list = ActiveRecord::Migrator.migrations(MIGRATIONS_ROOT + "/interleaved/pass_2")
    migrations = ActiveRecord::Migrator.new(:up, migration_list).pending_migrations

    assert_equal 1, migrations.size
    assert_equal migrations[0].version, 3
    assert_equal migrations[0].name, 'InterleavedInnocentJointable'
  end

  def test_deprecated_constructor
    assert_deprecated do
      ActiveRecord::Migrator.new(:up, MIGRATIONS_ROOT + "/interleaved/pass_2")
    end
  end

  def test_relative_migrations
    list = Dir.chdir(MIGRATIONS_ROOT) do
      ActiveRecord::Migrator.up("valid/", 1)
    end

    migration_proxy = list.find { |item|
      item.name == 'ValidPeopleHaveLastNames'
    }
    assert migration_proxy, 'should find pending migration'
  end

  def test_only_loads_pending_migrations
    # migrate up to 1
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)

    proxies = ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", nil)

    names = proxies.map(&:name)
    assert !names.include?('ValidPeopleHaveLastNames')
    assert names.include?('WeNeedReminders')
    assert names.include?('InnocentJointable')
  end

  def test_target_version_zero_should_run_only_once
    # migrate up to 1
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 1)

    # migrate down to 0
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 0)

    # migrate down to 0 again
    proxies = ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 0)
    assert_equal [], proxies
  end

  def test_migrator_db_has_no_schema_migrations_table
    # Oracle adapter raises error if semicolon is present as last character
    if current_adapter?(:OracleAdapter)
      ActiveRecord::Base.connection.execute("DROP TABLE schema_migrations")
    else
      ActiveRecord::Base.connection.execute("DROP TABLE schema_migrations;")
    end
    assert_nothing_raised do
      ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 1)
    end
  end

  def test_migrator_verbosity
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)
    assert_not_equal 0, ActiveRecord::Migration.message_count
    ActiveRecord::Migration.message_count = 0

    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", 0)
    assert_not_equal 0, ActiveRecord::Migration.message_count
    ActiveRecord::Migration.message_count = 0
  end

  def test_migrator_verbosity_off
    ActiveRecord::Migration.verbose = false
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)
    assert_equal 0, ActiveRecord::Migration.message_count
    ActiveRecord::Migrator.down(MIGRATIONS_ROOT + "/valid", 0)
    assert_equal 0, ActiveRecord::Migration.message_count
  end

  def test_migrator_going_down_due_to_version_target
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/valid", 1)
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 0)

    assert !Person.column_methods_hash.include?(:last_name)
    assert !Reminder.table_exists?

    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid")

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)
    assert Reminder.create("content" => "hello world", "remind_at" => Time.now)
    assert_equal "hello world", Reminder.find(:first).content
  end

  def test_migrator_rollback
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid")
    assert_equal(3, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal(2, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal(1, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal(0, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal(0, ActiveRecord::Migrator.current_version)
  end

  def test_migrator_forward
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid", 1)
    assert_equal(1, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.forward(MIGRATIONS_ROOT + "/valid", 2)
    assert_equal(3, ActiveRecord::Migrator.current_version)

    ActiveRecord::Migrator.forward(MIGRATIONS_ROOT + "/valid")
    assert_equal(3, ActiveRecord::Migrator.current_version)
  end

  def test_get_all_versions
    ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/valid")
    assert_equal([1,2,3], ActiveRecord::Migrator.get_all_versions)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal([1,2], ActiveRecord::Migrator.get_all_versions)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal([1], ActiveRecord::Migrator.get_all_versions)

    ActiveRecord::Migrator.rollback(MIGRATIONS_ROOT + "/valid")
    assert_equal([], ActiveRecord::Migrator.get_all_versions)
  end

  def test_schema_migrations_table_name
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    Reminder.reset_table_name
    assert_equal "prefix_schema_migrations_suffix", ActiveRecord::Migrator.schema_migrations_table_name
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    Reminder.reset_table_name
    assert_equal "schema_migrations", ActiveRecord::Migrator.schema_migrations_table_name
  ensure
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
  end

  def test_proper_table_name
    assert_equal "table", ActiveRecord::Migrator.proper_table_name('table')
    assert_equal "table", ActiveRecord::Migrator.proper_table_name(:table)
    assert_equal "reminders", ActiveRecord::Migrator.proper_table_name(Reminder)
    Reminder.reset_table_name
    assert_equal Reminder.table_name, ActiveRecord::Migrator.proper_table_name(Reminder)

    # Use the model's own prefix/suffix if a model is given
    ActiveRecord::Base.table_name_prefix = "ARprefix_"
    ActiveRecord::Base.table_name_suffix = "_ARsuffix"
    Reminder.table_name_prefix = 'prefix_'
    Reminder.table_name_suffix = '_suffix'
    Reminder.reset_table_name
    assert_equal "prefix_reminders_suffix", ActiveRecord::Migrator.proper_table_name(Reminder)
    Reminder.table_name_prefix = ''
    Reminder.table_name_suffix = ''
    Reminder.reset_table_name

    # Use AR::Base's prefix/suffix if string or symbol is given
    ActiveRecord::Base.table_name_prefix = "prefix_"
    ActiveRecord::Base.table_name_suffix = "_suffix"
    Reminder.reset_table_name
    assert_equal "prefix_table_suffix", ActiveRecord::Migrator.proper_table_name('table')
    assert_equal "prefix_table_suffix", ActiveRecord::Migrator.proper_table_name(:table)
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
    Reminder.reset_table_name
  end

  def test_rename_table_with_prefix_and_suffix
    assert !Thing.table_exists?
    ActiveRecord::Base.table_name_prefix = 'prefix_'
    ActiveRecord::Base.table_name_suffix = '_suffix'
    Thing.reset_table_name
    Thing.reset_sequence_name
    WeNeedThings.up

    assert Thing.create("content" => "hello world")
    assert_equal "hello world", Thing.find(:first).content

    RenameThings.up
    Thing.table_name = "prefix_awesome_things_suffix"

    assert_equal "hello world", Thing.find(:first).content
  ensure
    ActiveRecord::Base.table_name_prefix = ''
    ActiveRecord::Base.table_name_suffix = ''
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
    assert_equal "hello world", Reminder.find(:first).content

    WeNeedReminders.down
    assert_raise(ActiveRecord::StatementInvalid) { Reminder.find(:first) }
  ensure
    ActiveRecord::Base.table_name_prefix = ''
    ActiveRecord::Base.table_name_suffix = ''
    Reminder.reset_table_name
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

    if current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
      assert_equal '', data_column.default
    else
      assert_nil data_column.default
    end

    Person.connection.drop_table :binary_testings rescue nil
  end

  def test_migrator_with_duplicates
    assert_raise(ActiveRecord::DuplicateMigrationVersionError) do
      ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/duplicate", nil)
    end
  end

  def test_migrator_with_duplicate_names
    assert_raise(ActiveRecord::DuplicateMigrationNameError, "Multiple migrations have the name Chunky") do
      ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/duplicate_names", nil)
    end
  end

  def test_migrator_with_missing_version_numbers
    assert_raise(ActiveRecord::UnknownMigrationVersionError) do
      ActiveRecord::Migrator.migrate(MIGRATIONS_ROOT + "/missing", 500)
    end
  end

  def test_create_table_with_custom_sequence_name
    skip "not supported" unless current_adapter? :OracleAdapter

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

  protected
    def with_env_tz(new_tz = 'US/Eastern')
      old_tz, ENV['TZ'] = ENV['TZ'], new_tz
      yield
    ensure
      old_tz ? ENV['TZ'] = old_tz : ENV.delete('TZ')
    end
end

class InterleavedMigrationsTest < ActiveRecord::TestCase
  def test_migrator_interleaved_migrations
    ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/interleaved/pass_1")

    assert_nothing_raised do
      ActiveRecord::Migrator.up(MIGRATIONS_ROOT + "/interleaved/pass_2")
    end

    Person.reset_column_information
    assert Person.column_methods_hash.include?(:last_name)

    assert_nothing_raised do
      proxies = ActiveRecord::Migrator.down(
        MIGRATIONS_ROOT + "/interleaved/pass_3")
      names = proxies.map(&:name)
      assert names.include?('InterleavedPeopleHaveLastNames')
      assert names.include?('InterleavedInnocentJointable')
    end
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


class ChangeTableMigrationsTest < ActiveRecord::TestCase
  def setup
    @connection = Person.connection
    @connection.create_table :delete_me, :force => true do |t|
    end
  end

  def teardown
    Person.connection.drop_table :delete_me rescue nil
  end

  def test_references_column_type_adds_id
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, 'customer_id', :integer, {})
      t.references :customer
    end
  end

  def test_remove_references_column_type_removes_id
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, 'customer_id')
      t.remove_references :customer
    end
  end

  def test_add_belongs_to_works_like_add_references
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, 'customer_id', :integer, {})
      t.belongs_to :customer
    end
  end

  def test_remove_belongs_to_works_like_remove_references
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, 'customer_id')
      t.remove_belongs_to :customer
    end
  end

  def test_references_column_type_with_polymorphic_adds_type
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, 'taggable_type', :string, {})
      @connection.expects(:add_column).with(:delete_me, 'taggable_id', :integer, {})
      t.references :taggable, :polymorphic => true
    end
  end

  def test_remove_references_column_type_with_polymorphic_removes_type
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, 'taggable_type')
      @connection.expects(:remove_column).with(:delete_me, 'taggable_id')
      t.remove_references :taggable, :polymorphic => true
    end
  end

  def test_references_column_type_with_polymorphic_and_options_null_is_false_adds_table_flag
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, 'taggable_type', :string, {:null => false})
      @connection.expects(:add_column).with(:delete_me, 'taggable_id', :integer, {:null => false})
      t.references :taggable, :polymorphic => true, :null => false
    end
  end

  def test_remove_references_column_type_with_polymorphic_and_options_null_is_false_removes_table_flag
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, 'taggable_type')
      @connection.expects(:remove_column).with(:delete_me, 'taggable_id')
      t.remove_references :taggable, :polymorphic => true, :null => false
    end
  end

  def test_timestamps_creates_updated_at_and_created_at
    with_change_table do |t|
      @connection.expects(:add_timestamps).with(:delete_me)
      t.timestamps
    end
  end

  def test_remove_timestamps_creates_updated_at_and_created_at
    with_change_table do |t|
      @connection.expects(:remove_timestamps).with(:delete_me)
      t.remove_timestamps
    end
  end

  def string_column
    if current_adapter?(:PostgreSQLAdapter)
      "character varying(255)"
    elsif current_adapter?(:OracleAdapter)
      'VARCHAR2(255)'
    else
      'varchar(255)'
    end
  end

  def integer_column
    if current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
      'int(11)'
    elsif current_adapter?(:OracleAdapter)
      'NUMBER(38)'
    else
      'integer'
    end
  end

  def test_integer_creates_integer_column
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, :foo, integer_column, {})
      @connection.expects(:add_column).with(:delete_me, :bar, integer_column, {})
      t.integer :foo, :bar
    end
  end

  def test_string_creates_string_column
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, :foo, string_column, {})
      @connection.expects(:add_column).with(:delete_me, :bar, string_column, {})
      t.string :foo, :bar
    end
  end

  def test_column_creates_column
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, :bar, :integer, {})
      t.column :bar, :integer
    end
  end

  def test_column_creates_column_with_options
    with_change_table do |t|
      @connection.expects(:add_column).with(:delete_me, :bar, :integer, {:null => false})
      t.column :bar, :integer, :null => false
    end
  end

  def test_index_creates_index
    with_change_table do |t|
      @connection.expects(:add_index).with(:delete_me, :bar, {})
      t.index :bar
    end
  end

  def test_index_creates_index_with_options
    with_change_table do |t|
      @connection.expects(:add_index).with(:delete_me, :bar, {:unique => true})
      t.index :bar, :unique => true
    end
  end

  def test_index_exists
    with_change_table do |t|
      @connection.expects(:index_exists?).with(:delete_me, :bar, {})
      t.index_exists?(:bar)
    end
  end

  def test_index_exists_with_options
    with_change_table do |t|
      @connection.expects(:index_exists?).with(:delete_me, :bar, {:unique => true})
      t.index_exists?(:bar, :unique => true)
    end
  end

  def test_change_changes_column
    with_change_table do |t|
      @connection.expects(:change_column).with(:delete_me, :bar, :string, {})
      t.change :bar, :string
    end
  end

  def test_change_changes_column_with_options
    with_change_table do |t|
      @connection.expects(:change_column).with(:delete_me, :bar, :string, {:null => true})
      t.change :bar, :string, :null => true
    end
  end

  def test_change_default_changes_column
    with_change_table do |t|
      @connection.expects(:change_column_default).with(:delete_me, :bar, :string)
      t.change_default :bar, :string
    end
  end

  def test_remove_drops_single_column
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, [:bar])
      t.remove :bar
    end
  end

  def test_remove_drops_multiple_columns
    with_change_table do |t|
      @connection.expects(:remove_column).with(:delete_me, [:bar, :baz])
      t.remove :bar, :baz
    end
  end

  def test_remove_index_removes_index_with_options
    with_change_table do |t|
      @connection.expects(:remove_index).with(:delete_me, {:unique => true})
      t.remove_index :unique => true
    end
  end

  def test_rename_renames_column
    with_change_table do |t|
      @connection.expects(:rename_column).with(:delete_me, :bar, :baz)
      t.rename :bar, :baz
    end
  end

  protected
  def with_change_table
    Person.connection.change_table :delete_me do |t|
      yield t
    end
  end
end

if ActiveRecord::Base.connection.supports_bulk_alter?
  class BulkAlterTableMigrationsTest < ActiveRecord::TestCase
    def setup
      @connection = Person.connection
      @connection.create_table(:delete_me, :force => true) {|t| }
    end

    def teardown
      Person.connection.drop_table(:delete_me) rescue nil
    end

    def test_adding_multiple_columns
      assert_queries(1) do
        with_bulk_change_table do |t|
          t.column :name, :string
          t.string :qualification, :experience
          t.integer :age, :default => 0
          t.date :birthdate
          t.timestamps
        end
      end

      assert_equal 8, columns.size
      [:name, :qualification, :experience].each {|s| assert_equal :string, column(s).type }
      assert_equal 0, column(:age).default
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
      assert_queries(3) do
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
    assert File.exists?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exists?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
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

    sources = ActiveSupport::OrderedHash.new
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy"
    sources[:omg] = MIGRATIONS_ROOT + "/to_copy2"
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert File.exists?(@migrations_path + "/4_people_have_hobbies.bukkits.rb")
    assert File.exists?(@migrations_path + "/5_people_have_descriptions.bukkits.rb")
    assert File.exists?(@migrations_path + "/6_create_articles.omg.rb")
    assert File.exists?(@migrations_path + "/7_create_comments.omg.rb")

    files_count = Dir[@migrations_path + "/*.rb"].length
    ActiveRecord::Migration.copy(@migrations_path, sources)
    assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
  ensure
    clear
  end

  def test_copying_migrations_with_timestamps
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    Time.travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exists?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
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

    sources = ActiveSupport::OrderedHash.new
    sources[:bukkits] = MIGRATIONS_ROOT + "/to_copy_with_timestamps"
    sources[:omg]     = MIGRATIONS_ROOT + "/to_copy_with_timestamps2"

    Time.travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, sources)
      assert File.exists?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100726101012_create_articles.omg.rb")
      assert File.exists?(@migrations_path + "/20100726101013_create_comments.omg.rb")
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

    Time.travel_to(Time.utc(2010, 2, 20, 10, 10, 10)) do
      ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exists?(@migrations_path + "/20100301010102_people_have_hobbies.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100301010103_people_have_descriptions.bukkits.rb")

      files_count = Dir[@migrations_path + "/*.rb"].length
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert_equal files_count, Dir[@migrations_path + "/*.rb"].length
      assert copied.empty?
    end
  ensure
    clear
  end

  def test_skipping_migrations
    @migrations_path = MIGRATIONS_ROOT + "/valid_with_timestamps"
    @existing_migrations = Dir[@migrations_path + "/*.rb"]

    sources = ActiveSupport::OrderedHash.new
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

    sources = ActiveSupport::OrderedHash.new
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

    Time.travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exists?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
    Dir.delete(@migrations_path)
  end

  def test_copying_migrations_to_empty_directory
    @migrations_path = MIGRATIONS_ROOT + "/empty"
    @existing_migrations = []

    Time.travel_to(Time.utc(2010, 7, 26, 10, 10, 10)) do
      copied = ActiveRecord::Migration.copy(@migrations_path, {:bukkits => MIGRATIONS_ROOT + "/to_copy_with_timestamps"})
      assert File.exists?(@migrations_path + "/20100726101010_people_have_hobbies.bukkits.rb")
      assert File.exists?(@migrations_path + "/20100726101011_people_have_descriptions.bukkits.rb")
      assert_equal 2, copied.length
    end
  ensure
    clear
  end
end
