require "cases/helper"
require 'support/schema_dumping_helper'
require 'models/topic'
require 'models/reply'
require 'models/subscriber'
require 'models/movie'
require 'models/keyboard'
require 'models/mixed_case_monkey'
require 'models/dashboard'

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
    assert_nothing_raised { topic.save! }
    id = topic.id

    topicReloaded = Topic.find(id)
    assert_equal("New Topic", topicReloaded.title)
  end

  def test_customized_primary_key_auto_assigns_on_save
    Keyboard.delete_all
    keyboard = Keyboard.new(:name => 'HHKB')
    assert_nothing_raised { keyboard.save! }
    assert_equal keyboard.id, Keyboard.find_by_name('HHKB').id
  end

  def test_customized_primary_key_can_be_get_before_saving
    keyboard = Keyboard.new
    assert_nil keyboard.id
    assert_nothing_raised { assert_nil keyboard.key_number }
  end

  def test_customized_string_primary_key_settable_before_save
    subscriber = Subscriber.new
    assert_nothing_raised { subscriber.id = 'webster123' }
    assert_equal 'webster123', subscriber.id
    assert_equal 'webster123', subscriber.nick
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
    assert_nothing_raised { subscriber.save! }
    assert_equal("jdoe", subscriber.id)

    subscriberReloaded = Subscriber.find("jdoe")
    assert_equal("John Doe", subscriberReloaded.name)
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
    assert_nothing_raised { MixedCaseMonkey.update_counters(1, :fleaCount => 99) }
  end
  def test_find_with_one_id_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1) }
  end
  def test_find_with_multiple_ids_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find([1,2]) }
  end
  def test_instance_update_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1).save }
  end
  def test_instance_destroy_should_quote_pkey
    assert_nothing_raised { MixedCaseMonkey.find(1).destroy }
  end

  def test_supports_primary_key
    assert_nothing_raised NoMethodError do
      ActiveRecord::Base.connection.supports_primary_key?
    end
  end

  def test_primary_key_returns_value_if_it_exists
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'developers'
    end

    if ActiveRecord::Base.connection.supports_primary_key?
      assert_equal 'id', klass.primary_key
    end
  end

  def test_primary_key_returns_nil_if_it_does_not_exist
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'developers_projects'
    end

    if ActiveRecord::Base.connection.supports_primary_key?
      assert_nil klass.primary_key
    end
  end

  def test_quoted_primary_key_after_set_primary_key
    k = Class.new( ActiveRecord::Base )
    assert_equal k.connection.quote_column_name("id"), k.quoted_primary_key
    k.primary_key = "foo"
    assert_equal k.connection.quote_column_name("foo"), k.quoted_primary_key
  end

  def test_auto_detect_primary_key_from_schema
    MixedCaseMonkey.reset_primary_key
    assert_equal "monkeyID", MixedCaseMonkey.primary_key
  end

  def test_primary_key_update_with_custom_key_name
    dashboard = Dashboard.create!(dashboard_id: '1')
    dashboard.id = '2'
    dashboard.save!

    dashboard = Dashboard.first
    assert_equal '2', dashboard.id
  end
end

class PrimaryKeyWithNoConnectionTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  unless in_memory_db?
    def test_set_primary_key_with_no_connection
      connection = ActiveRecord::Base.remove_connection

      model = Class.new(ActiveRecord::Base)
      model.primary_key = 'foo'

      assert_equal 'foo', model.primary_key

      ActiveRecord::Base.establish_connection(connection)

      assert_equal 'foo', model.primary_key
    end
  end
end

class PrimaryKeyAnyTypeTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  self.use_transactional_fixtures = false

  class Barcode < ActiveRecord::Base
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:barcodes, primary_key: "code", id: :string, limit: 42, force: true)
  end

  teardown do
    @connection.execute("DROP TABLE IF EXISTS barcodes")
  end

  def test_any_type_primary_key
    assert_equal "code", Barcode.primary_key

    column_type = Barcode.type_for_attribute(Barcode.primary_key)
    assert_equal :string, column_type.type
    assert_equal 42, column_type.limit
  end

  test "schema dump primary key includes type and options" do
    schema = dump_table_schema "barcodes"
    assert_match %r{create_table "barcodes", primary_key: "code", id: :string, limit: 42}, schema
  end
end

if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
  class PrimaryKeyWithAnsiQuotesTest < ActiveRecord::TestCase
    self.use_transactional_fixtures = false

    def test_primary_key_method_with_ansi_quotes
      con = ActiveRecord::Base.connection
      con.execute("SET SESSION sql_mode='ANSI_QUOTES'")
      assert_equal "id", con.primary_key("topics")
    ensure
      con.reconnect!
    end
  end
end

if current_adapter?(:PostgreSQLAdapter, :MysqlAdapter, :Mysql2Adapter)
  class PrimaryKeyBigSerialTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    self.use_transactional_fixtures = false

    class Widget < ActiveRecord::Base
    end

    setup do
      @connection = ActiveRecord::Base.connection
      if current_adapter?(:PostgreSQLAdapter)
        @connection.create_table(:widgets, id: :bigserial, force: true)
      else
        @connection.create_table(:widgets, id: :bigint, force: true)
      end
    end

    teardown do
      @connection.execute("DROP TABLE IF EXISTS widgets")
    end

    test "primary key column type with bigserial" do
      column_type = Widget.type_for_attribute(Widget.primary_key)
      assert_equal :integer, column_type.type
      assert_equal 8, column_type.limit
    end

    test "primary key with bigserial are automatically numbered" do
      widget = Widget.create!
      assert_not_nil widget.id
    end

    test "schema dump primary key with bigserial" do
      schema = dump_table_schema "widgets"
      if current_adapter?(:PostgreSQLAdapter)
        assert_match %r{create_table "widgets", id: :bigserial}, schema
      else
        assert_match %r{create_table "widgets", id: :bigint}, schema
      end
    end
  end
end
