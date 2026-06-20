# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"
require "support/stubs/strong_parameters"

class PostgresqlHstoreTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  class Hstore < ActiveRecord::Base
    self.table_name = "hstores"

    store_accessor :settings, :language, :timezone
  end

  def setup
    @connection = ActiveRecord::Base.lease_connection

    enable_extension!("hstore", @connection)

    @connection.transaction do
      @connection.create_table("hstores") do |t|
        t.hstore "tags", default: ""
        t.hstore "payload", array: true
        t.hstore "settings"
      end
    end
    Hstore.reset_column_information
    @column = Hstore.columns_hash["tags"]
    @type = Hstore.type_for_attribute("tags")
  end

  teardown do
    @connection.drop_table "hstores", if_exists: true
    disable_extension!("hstore", @connection)
  end

  def test_hstore_included_in_extensions
    assert_respond_to @connection, :extensions
    assert_includes @connection.extensions, "hstore", "extension list should include hstore"
  end

  def test_disable_enable_hstore
    assert @connection.extension_enabled?("hstore")
    @connection.disable_extension "hstore", force: :cascade
    assert_not @connection.extension_enabled?("hstore")
    @connection.enable_extension "hstore"
    assert @connection.extension_enabled?("hstore")
  ensure
    # Restore column(s) dropped by `drop extension hstore cascade;`
    load_schema
  end

  def test_type_for_column_resolves_extension_type_when_cast_type_is_missing
    # A schema cache dumped against another database carries an hstore OID this
    # one lacks, so the cached cast type comes back nil. It must still resolve via
    # the portable SQL type name -- for scalar and array columns alike.
    @connection.create_table("hstore_oid_cache_test", force: true) do |t|
      t.hstore "data"
      t.hstore "labels", array: true
    end
    klass = Class.new(ActiveRecord::Base) { self.table_name = "hstore_oid_cache_test" }
    columns = @connection.columns("hstore_oid_cache_test").index_by(&:name)

    scalar = ActiveRecord::ConnectionAdapters::PostgreSQL::Column.new(
      "data", nil, nil, columns["data"].sql_type_metadata, columns["data"].null
    )
    array = ActiveRecord::ConnectionAdapters::PostgreSQL::Column.new(
      "labels", nil, nil, columns["labels"].sql_type_metadata, columns["labels"].null
    )
    assert_nil scalar.cast_type
    assert_nil array.cast_type

    # Drop hstore (a base type, not bulk-loaded) from the type map so the fallback
    # fetches the OID on demand -- the state an unknown local OID produces.
    @connection.reload_type_map

    assert_instance_of ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Hstore,
      klass.send(:type_for_column, scalar)

    array_type = klass.send(:type_for_column, array)
    assert_instance_of ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array, array_type
    assert_instance_of ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Hstore, array_type.subtype
  ensure
    @connection.drop_table("hstore_oid_cache_test", if_exists: true)
  end

  def test_standard_columns_do_not_trigger_a_type_lookup
    # The fallback fires only for nil cached cast types; standard types resolve
    # from the static map and must never emit a `::regtype` lookup.
    @connection.create_table("hstore_plain", force: true) do |t|
      t.string :name
      t.integer :count
      t.boolean :flag
    end
    klass = Class.new(ActiveRecord::Base) { self.table_name = "hstore_plain" }
    klass.create!(name: "x", count: 1, flag: true) # warm the schema

    type_lookups = 0
    counter = ->(*, payload) { type_lookups += 1 if payload[:sql] =~ /::regtype/ }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      klass.reset_column_information
      record = klass.create!(name: "y", count: 2, flag: false)
      assert_equal [2, false], [record.reload.count, record.flag]
    end

    assert_equal 0, type_lookups
  ensure
    @connection.drop_table("hstore_plain", if_exists: true)
  end

  def test_lookup_cast_type_raises_a_clean_error_for_a_missing_type
    # A cache so stale the type no longer exists must surface the database error,
    # not loop or raise an opaque Ruby error.
    assert_raises(ActiveRecord::StatementInvalid) do
      # Wrapped in a savepoint so the deliberately failing lookup doesn't abort
      # the surrounding test transaction.
      @connection.transaction(requires_new: true) do
        @connection.lookup_cast_type("a_type_that_does_not_exist")
      end
    end
  end

  def test_column
    assert_equal :hstore, @column.type
    assert_equal "hstore", @column.sql_type
    assert_not_predicate @column, :array?

    assert_not_predicate @type, :binary?
  end

  def test_default
    @connection.add_column "hstores", "permissions", :hstore, default: '"users"=>"read", "articles"=>"write"'
    Hstore.reset_column_information

    assert_equal({ "users" => "read", "articles" => "write" }, Hstore.column_defaults["permissions"])
    assert_equal({ "users" => "read", "articles" => "write" }, Hstore.new.permissions)
  ensure
    Hstore.reset_column_information
  end

  def test_change_table_supports_hstore
    @connection.transaction do
      @connection.change_table("hstores") do |t|
        t.hstore "users", default: ""
      end
      Hstore.reset_column_information
      column = Hstore.columns_hash["users"]
      assert_equal :hstore, column.type

      raise ActiveRecord::Rollback # reset the schema change
    end
  ensure
    Hstore.reset_column_information
  end

  def test_hstore_migration
    hstore_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        change_table("hstores") do |t|
          t.hstore :keys
        end
      end
    end

    hstore_migration.new.suppress_messages do
      hstore_migration.migrate(:up)
      assert_includes @connection.columns(:hstores).map(&:name), "keys"
      hstore_migration.migrate(:down)
      assert_not_includes @connection.columns(:hstores).map(&:name), "keys"
    end
  end

  def test_cast_value_on_write
    x = Hstore.new tags: { "bool" => true, "number" => 5 }
    assert_equal({ "bool" => true, "number" => 5 }, x.tags_before_type_cast)
    assert_equal({ "bool" => "true", "number" => "5" }, x.tags)
    x.save
    assert_equal({ "bool" => "true", "number" => "5" }, x.reload.tags)
  end

  def test_type_cast_hstore
    assert_equal({ "1" => "2" }, @type.deserialize("\"1\"=>\"2\""))
    assert_equal({}, @type.deserialize(""))
    assert_cycle("key" => nil)
    assert_cycle("c" => "}", '"a"' => 'b "a b')
  end

  def test_with_store_accessors
    x = Hstore.new(language: "fr", timezone: "GMT")
    assert_equal "fr", x.language
    assert_equal "GMT", x.timezone

    x.save!
    x = Hstore.first
    assert_equal "fr", x.language
    assert_equal "GMT", x.timezone

    x.language = "de"
    x.save!

    x = Hstore.first
    assert_equal "de", x.language
    assert_equal "GMT", x.timezone
  end

  def test_duplication_with_store_accessors
    x = Hstore.new(language: "fr", timezone: "GMT")
    assert_equal "fr", x.language
    assert_equal "GMT", x.timezone

    y = x.dup
    assert_equal "fr", y.language
    assert_equal "GMT", y.timezone
  end

  def test_yaml_round_trip_with_store_accessors
    x = Hstore.new(language: "fr", timezone: "GMT")
    assert_equal "fr", x.language
    assert_equal "GMT", x.timezone

    payload = YAML.dump(x)
    y = YAML.unsafe_load(payload)
    assert_equal "fr", y.language
    assert_equal "GMT", y.timezone
  end

  def test_changes_with_store_accessors
    x = Hstore.new(language: "de")
    assert_predicate x, :language_changed?
    assert_nil x.language_was
    assert_equal [nil, "de"], x.language_change
    x.save!

    assert_not x.language_changed?
    x.reload

    x.settings = nil
    assert_predicate x, :language_changed?
    assert_equal "de", x.language_was
    assert_equal ["de", nil], x.language_change
  end

  def test_changes_in_place
    hstore = Hstore.create!(settings: { "one" => "two" })
    hstore.settings["three"] = "four"
    hstore.save!
    hstore.reload

    assert_equal "four", hstore.settings["three"]
    assert_not_predicate hstore, :changed?
  end

  def test_dirty_from_user_equal
    settings = { "alongkey" => "anything", "key" => "value" }
    hstore = Hstore.create!(settings: settings)

    hstore.settings = { "key" => "value", "alongkey" => "anything" }
    assert_equal settings, hstore.settings
    assert_not_predicate hstore, :changed?
  end

  def test_hstore_dirty_from_database_equal
    settings = { "alongkey" => "anything", "key" => "value" }
    hstore = Hstore.create!(settings: settings)
    hstore.reload

    assert_equal settings, hstore.settings
    hstore.settings = settings
    assert_not_predicate hstore, :changed?
  end

  def test_spaces
    assert_cycle(" " => " ")
  end

  def test_commas
    assert_cycle("," => "")
  end

  def test_signs
    assert_cycle("=" => ">")
  end

  def test_various_null
    assert_cycle({ "a" => nil, "b" => nil, "c" => "NuLl", "null" => "c" })
  end

  def test_equal_signs
    assert_cycle("=a" => "q=w")
  end

  def test_parse5
    assert_cycle("=a" => "q=w")
  end

  def test_parse6
    assert_cycle("\"a" => "q>w")
  end

  def test_parse7
    assert_cycle("\"a" => "q\"w")
  end

  def test_rewrite
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    x.tags = { '"a\'' => "b" }
    assert x.save!
  end

  def test_select
    @connection.execute "insert into hstores (tags) VALUES ('1=>2')"
    x = Hstore.first
    assert_equal({ "1" => "2" }, x.tags)
  end

  def test_array_cycle
    assert_array_cycle([{ "AA" => "BB", "CC" => "DD" }, { "AA" => nil }])
  end

  def test_array_strings_with_quotes
    assert_array_cycle([{ "this has" => 'some "s that need to be escaped"' }])
  end

  def test_array_strings_with_commas
    assert_array_cycle([{ "this,has" => "many,values" }])
  end

  def test_array_strings_with_array_delimiters
    assert_array_cycle(["{" => "}"])
  end

  def test_array_strings_with_null_strings
    assert_array_cycle([{ "NULL" => "NULL" }])
  end

  def test_contains_nils
    assert_array_cycle([{ "NULL" => nil }])
  end

  def test_select_multikey
    @connection.execute "insert into hstores (tags) VALUES ('1=>2,2=>3')"
    x = Hstore.first
    assert_equal({ "1" => "2", "2" => "3" }, x.tags)
  end

  def test_create
    assert_cycle("a" => "b", "1" => "2")
  end

  def test_nil
    assert_cycle("a" => nil)
  end

  def test_quotes
    assert_cycle("a" => 'b"ar', '1"foo' => "2")
  end

  def test_whitespace
    assert_cycle("a b" => "b ar", '1"foo' => "2")
  end

  def test_backslash
    assert_cycle('a\\b' => 'b\\ar', '1"foo' => "2")
    assert_cycle('a\\"' => 'b\\ar', '1"foo' => "2")
    assert_cycle("a\\" => "bar\\", '1"foo' => "2")
  end

  def test_comma
    assert_cycle("a, b" => "bar", '1"foo' => "2")
  end

  def test_arrow
    assert_cycle("a=>b" => "bar", '1"foo' => "2")
  end

  def test_quoting_special_characters
    assert_cycle("ca" => "cà", "ac" => "àc")
  end

  def test_multiline
    assert_cycle("a\nb" => "c\nd")
  end

  class TagCollection
    def initialize(hash); @hash = hash end
    def to_hash; @hash end
    def self.load(hash); new(hash) end
    def self.dump(object); object.to_hash end
  end

  class HstoreWithSerialize < Hstore
    serialize :tags, coder: TagCollection
  end

  def test_hstore_with_serialized_attributes
    HstoreWithSerialize.create! tags: TagCollection.new("one" => "two")
    record = HstoreWithSerialize.first
    assert_instance_of TagCollection, record.tags
    assert_equal({ "one" => "two" }, record.tags.to_hash)
    record.tags = TagCollection.new("three" => "four")
    record.save!
    assert_equal({ "three" => "four" }, HstoreWithSerialize.first.tags.to_hash)
  end

  def test_clone_hstore_with_serialized_attributes
    HstoreWithSerialize.create! tags: TagCollection.new("one" => "two")
    record = HstoreWithSerialize.first
    dupe = record.dup
    assert_equal({ "one" => "two" }, dupe.tags.to_hash)
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema("hstores")
    assert_match %r[t\.hstore "tags",\s+default: {}], output
  end

  def test_supports_to_unsafe_h_values
    assert_equal "\"hi\"=>\"hi\"", @type.serialize(ProtectedParams.new("hi" => "hi"))
  end

  private
    def assert_array_cycle(array)
      # test creation
      x = Hstore.create!(payload: array)
      x.reload
      assert_equal(array, x.payload)

      # test updating
      x = Hstore.create!(payload: [])
      x.payload = array
      x.save!
      x.reload
      assert_equal(array, x.payload)
    end

    def assert_cycle(hash)
      # test creation
      x = Hstore.create!(tags: hash)
      x.reload
      assert_equal(hash, x.tags)

      # test updating
      x = Hstore.create!(tags: {})
      x.tags = hash
      x.save!
      x.reload
      assert_equal(hash, x.tags)
    end
end
