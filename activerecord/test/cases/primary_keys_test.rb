# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"
require "models/topic"
require "models/reply"
require "models/subscriber"
require "models/movie"
require "models/keyboard"
require "models/mixed_case_monkey"
require "models/dashboard"
require "models/non_primary_key"

class PrimaryKeysTest < ActiveRecord::TestCase
  fixtures :topics, :subscribers, :movies, :mixed_case_monkeys

  def test_to_key_with_default_primary_key
    topic = Topic.new
    assert_nil topic.to_key
    topic = Topic.find(1)
    assert_equal [1], topic.to_key
  end

  def test_to_key_with_customized_primary_key
    keyboard = Keyboard.new
    assert_nil keyboard.to_key
    keyboard.save
    assert_equal keyboard.to_key, [keyboard.id]
  end

  def test_read_attribute_with_custom_primary_key
    keyboard = Keyboard.create!
    assert_equal keyboard.key_number, keyboard.read_attribute(:id)
  end

  def test_to_key_with_primary_key_after_destroy
    topic = Topic.find(1)
    topic.destroy
    assert_equal [1], topic.to_key
  end

  def test_integer_key
    topic = Topic.find(1)
    assert_equal(topics(:first).author_name, topic.author_name)
    topic = Topic.find(2)
    assert_equal(topics(:second).author_name, topic.author_name)

    topic = Topic.new
    topic.title = "New Topic"
    assert_nil topic.id
    topic.save!
    id = topic.id

    topicReloaded = Topic.find(id)
    assert_equal("New Topic", topicReloaded.title)
  end

  def test_customized_primary_key_auto_assigns_on_save
    Keyboard.delete_all
    keyboard = Keyboard.new(name: "HHKB")
    keyboard.save!
    assert_equal keyboard.id, Keyboard.find_by_name("HHKB").id
  end

  def test_customized_primary_key_can_be_get_before_saving
    keyboard = Keyboard.new
    assert_nil keyboard.id
    assert_nil keyboard.key_number
  end

  def test_customized_string_primary_key_settable_before_save
    subscriber = Subscriber.new
    subscriber.id = "webster123"
    assert_equal "webster123", subscriber.id
    assert_equal "webster123", subscriber.nick
  end

  def test_update_with_non_primary_key_id_column
    subscriber = Subscriber.first
    subscriber.update(update_count: 1)
    subscriber.reload
    assert_equal 1, subscriber.update_count
  end

  def test_update_columns_with_non_primary_key_id_column
    subscriber = Subscriber.first
    subscriber.update_columns(id: 1)
    assert_not_equal 1, subscriber.nick
  end

  def test_string_key
    subscriber = Subscriber.find(subscribers(:first).nick)
    assert_equal(subscribers(:first).name, subscriber.name)
    subscriber = Subscriber.find(subscribers(:second).nick)
    assert_equal(subscribers(:second).name, subscriber.name)

    subscriber = Subscriber.new
    subscriber.id = "jdoe"
    assert_equal("jdoe", subscriber.id)
    subscriber.name = "John Doe"
    subscriber.save!
    assert_equal("jdoe", subscriber.id)

    subscriberReloaded = Subscriber.find("jdoe")
    assert_equal("John Doe", subscriberReloaded.name)
  end

  def test_id_column_that_is_not_primary_key
    NonPrimaryKey.create!(id: 100)
    actual = NonPrimaryKey.find_by(id: 100)
    assert_match %r{<NonPrimaryKey id: 100}, actual.inspect
  end

  def test_find_with_more_than_one_string_key
    assert_equal 2, Subscriber.find(subscribers(:first).nick, subscribers(:second).nick).length
  end

  def test_primary_key_prefix
    old_primary_key_prefix_type = ActiveRecord::Base.primary_key_prefix_type
    ActiveRecord::Base.primary_key_prefix_type = :table_name
    Topic.reset_primary_key
    assert_equal "topicid", Topic.primary_key

    ActiveRecord::Base.primary_key_prefix_type = :table_name_with_underscore
    Topic.reset_primary_key
    assert_equal "topic_id", Topic.primary_key

    ActiveRecord::Base.primary_key_prefix_type = nil
    Topic.reset_primary_key
    assert_equal "id", Topic.primary_key
  ensure
    ActiveRecord::Base.primary_key_prefix_type = old_primary_key_prefix_type
  end

  def test_delete_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.delete(1) }
  end

  def test_update_counters_should_quote_pkey_and_quote_counter_columns
    assert_nothing_raised { MixedCaseMonkey.update_counters(1, fleaCount: 99) }
  end

  def test_find_with_one_id_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1) }
  end

  def test_find_with_multiple_ids_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find([1, 2]) }
  end

  def test_instance_update_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1).save }
  end

  def test_instance_destroy_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1).destroy }
  end

  def test_primary_key_returns_value_if_it_exists
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "developers"
    end

    assert_equal "id", klass.primary_key
  end

  def test_primary_key_returns_nil_if_it_does_not_exist
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "developers_projects"
    end

    assert_nil klass.primary_key
  end

  def test_quoted_primary_key_after_set_primary_key
    k = Class.new(ActiveRecord::Base)
    k.table_name = "bar"
    assert_equal k.connection.quote_column_name("id"), k.quoted_primary_key
    k.primary_key = "foo"
    assert_equal k.connection.quote_column_name("foo"), k.quoted_primary_key
  end

  def test_auto_detect_primary_key_from_schema
    MixedCaseMonkey.reset_primary_key
    assert_equal "monkeyID", MixedCaseMonkey.primary_key
  end

  def test_primary_key_update_with_custom_key_name
    dashboard = Dashboard.create!(dashboard_id: "1")
    dashboard.id = "2"
    dashboard.save!

    dashboard = Dashboard.first
    assert_equal "2", dashboard.id
  end

  def test_create_without_primary_key_no_extra_query
    skip if current_adapter?(:OracleAdapter)

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "dashboards"
    end
    klass.create! # warmup schema cache
    assert_queries(3, ignore_none: true) { klass.create! }
  end

  def test_assign_id_raises_error_if_primary_key_doesnt_exist
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "dashboards"
    end
    dashboard = klass.new
    assert_raises(ActiveModel::MissingAttributeError) { dashboard.id = "1" }
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_serial_with_quoted_sequence_name
      column = MixedCaseMonkey.columns_hash[MixedCaseMonkey.primary_key]
      assert_equal "nextval('\"mixed_case_monkeys_monkeyID_seq\"'::regclass)", column.default_function
      assert_predicate column, :serial?
    end

    def test_serial_with_unquoted_sequence_name
      column = Topic.columns_hash[Topic.primary_key]
      assert_equal "nextval('topics_id_seq'::regclass)", column.default_function
      assert_predicate column, :serial?
    end
  end
end

class PrimaryKeyWithNoConnectionTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  unless in_memory_db?
    def test_set_primary_key_with_no_connection
      connection = ActiveRecord::Base.remove_connection

      model = Class.new(ActiveRecord::Base)
      model.primary_key = "foo"

      assert_equal "foo", model.primary_key

      ActiveRecord::Base.establish_connection(connection)

      assert_equal "foo", model.primary_key
    end
  end
end

class PrimaryKeyWithAutoIncrementTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  class AutoIncrement < ActiveRecord::Base
  end

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table(:auto_increments, if_exists: true)
  end

  def test_primary_key_with_integer
    @connection.create_table(:auto_increments, id: :integer, force: true)
    assert_auto_incremented
  end

  def test_primary_key_with_bigint
    @connection.create_table(:auto_increments, id: :bigint, force: true)
    assert_auto_incremented
  end

  private
    def assert_auto_incremented
      record1 = AutoIncrement.create!
      assert_not_nil record1.id

      record1.destroy

      record2 = AutoIncrement.create!
      assert_not_nil record2.id
      assert_operator record2.id, :>, record1.id
    end
end

class PrimaryKeyAnyTypeTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  class Barcode < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:barcodes, primary_key: "code", id: :string, limit: 42, force: true)
  end

  teardown do
    @connection.drop_table(:barcodes, if_exists: true)
  end

  def test_any_type_primary_key
    assert_equal "code", Barcode.primary_key

    column = Barcode.column_for_attribute(Barcode.primary_key)
    assert_not column.null
    assert_equal :string, column.type
    assert_equal 42, column.limit
  ensure
    Barcode.reset_column_information
  end

  test "schema dump primary key includes type and options" do
    schema = dump_table_schema "barcodes"
    assert_match %r/create_table "barcodes", primary_key: "code", id: { type: :string, limit: 42 }/, schema
    assert_no_match %r{t\.index \["code"\]}, schema
  end

  if current_adapter?(:Mysql2Adapter) && supports_datetime_with_precision?
    test "schema typed primary key column" do
      @connection.create_table(:scheduled_logs, id: :timestamp, precision: 6, force: true)
      schema = dump_table_schema("scheduled_logs")
      assert_match %r/create_table "scheduled_logs", id: :timestamp.*/, schema
    end
  end
end

class CompositePrimaryKeyTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.schema_cache.clear!
    @connection.create_table(:uber_barcodes, primary_key: ["region", "code"], force: true) do |t|
      t.string :region
      t.integer :code
    end
    @connection.create_table(:barcodes_reverse, primary_key: ["code", "region"], force: true) do |t|
      t.string :region
      t.integer :code
    end
    @connection.create_table(:travels, primary_key: ["from", "to"], force: true) do |t|
      t.string :from
      t.string :to
    end
  end

  def teardown
    @connection.drop_table :uber_barcodes, if_exists: true
    @connection.drop_table :barcodes_reverse, if_exists: true
    @connection.drop_table :travels, if_exists: true
  end

  def test_composite_primary_key
    assert_equal ["region", "code"], @connection.primary_keys("uber_barcodes")
  end

  def test_composite_primary_key_with_reserved_words
    assert_equal ["from", "to"], @connection.primary_keys("travels")
  end

  def test_composite_primary_key_out_of_order
    assert_equal ["code", "region"], @connection.primary_keys("barcodes_reverse")
  end

  def test_primary_key_issues_warning
    model = Class.new(ActiveRecord::Base) do
      def self.table_name
        "uber_barcodes"
      end
    end
    warning = capture(:stderr) do
      assert_nil model.primary_key
    end
    assert_match(/WARNING: Active Record does not support composite primary key\./, warning)
  end

  def test_collectly_dump_composite_primary_key
    schema = dump_table_schema "uber_barcodes"
    assert_match %r{create_table "uber_barcodes", primary_key: \["region", "code"\]}, schema
  end

  def test_dumping_composite_primary_key_out_of_order
    schema = dump_table_schema "barcodes_reverse"
    assert_match %r{create_table "barcodes_reverse", primary_key: \["code", "region"\]}, schema
  end
end

class PrimaryKeyIntegerNilDefaultTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  self.use_transactional_tests = false

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def teardown
    @connection.drop_table :int_defaults, if_exists: true
  end

  def test_schema_dump_primary_key_integer_with_default_nil
    skip if current_adapter?(:SQLite3Adapter)
    @connection.create_table(:int_defaults, id: :integer, default: nil, force: true)
    schema = dump_table_schema "int_defaults"
    assert_match %r{create_table "int_defaults", id: :integer, default: nil}, schema
  end

  def test_schema_dump_primary_key_bigint_with_default_nil
    @connection.create_table(:int_defaults, id: :bigint, default: nil, force: true)
    schema = dump_table_schema "int_defaults"
    assert_match %r{create_table "int_defaults", id: :bigint, default: nil}, schema
  end
end

if current_adapter?(:PostgreSQLAdapter, :Mysql2Adapter)
  class PrimaryKeyIntegerTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    self.use_transactional_tests = false

    class Widget < ActiveRecord::Base
    end

    setup do
      @connection = ActiveRecord::Base.connection
      @pk_type = current_adapter?(:PostgreSQLAdapter) ? :serial : :integer
    end

    teardown do
      @connection.drop_table :widgets, if_exists: true
    end

    test "primary key column type with serial/integer" do
      @connection.create_table(:widgets, id: @pk_type, force: true)
      column = @connection.columns(:widgets).find { |c| c.name == "id" }
      assert_equal :integer, column.type
      assert_not_predicate column, :bigint?
    end

    test "primary key with serial/integer are automatically numbered" do
      @connection.create_table(:widgets, id: @pk_type, force: true)
      widget = Widget.create!
      assert_not_nil widget.id
    end

    test "schema dump primary key with serial/integer" do
      @connection.create_table(:widgets, id: @pk_type, force: true)
      schema = dump_table_schema "widgets"
      assert_match %r{create_table "widgets", id: :#{@pk_type}, }, schema
    end

    if current_adapter?(:Mysql2Adapter)
      test "primary key column type with options" do
        @connection.create_table(:widgets, id: :primary_key, limit: 4, unsigned: true, force: true)
        column = @connection.columns(:widgets).find { |c| c.name == "id" }
        assert_predicate column, :auto_increment?
        assert_equal :integer, column.type
        assert_not_predicate column, :bigint?
        assert_predicate column, :unsigned?

        schema = dump_table_schema "widgets"
        assert_match %r/create_table "widgets", id: { type: :integer, unsigned: true }/, schema
      end

      test "bigint primary key with unsigned" do
        @connection.create_table(:widgets, id: :bigint, unsigned: true, force: true)
        column = @connection.columns(:widgets).find { |c| c.name == "id" }
        assert_predicate column, :auto_increment?
        assert_equal :integer, column.type
        assert_predicate column, :bigint?
        assert_predicate column, :unsigned?

        schema = dump_table_schema "widgets"
        assert_match %r/create_table "widgets", id: { type: :bigint, unsigned: true }/, schema
      end
    end
  end
end
