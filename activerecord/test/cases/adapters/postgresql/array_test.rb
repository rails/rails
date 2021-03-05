# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class PostgresqlArrayTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper
  include InTimeZone

  class PgArray < ActiveRecord::Base
    self.table_name = "pg_arrays"
  end

  def setup
    @connection = ActiveRecord::Base.connection

    enable_extension!("hstore", @connection)

    @connection.transaction do
      @connection.create_table "pg_arrays", force: true do |t|
        t.string "tags", array: true, limit: 255
        t.integer "ratings", array: true
        t.datetime :datetimes, array: true
        t.hstore :hstores, array: true
        t.decimal :decimals, array: true, default: [], precision: 10, scale: 2
        t.timestamp :timestamps, array: true, default: [], precision: 6
        t.binary :signatures, array: true
      end
    end
    PgArray.reset_column_information
    @column = PgArray.columns_hash["tags"]
    @type = PgArray.type_for_attribute("tags")
  end

  teardown do
    @connection.drop_table "pg_arrays", if_exists: true
    disable_extension!("hstore", @connection)
  end

  def test_column
    assert_equal :string, @column.type
    assert_equal "character varying(255)", @column.sql_type
    assert_predicate @column, :array?
    assert_not_predicate @type, :binary?

    ratings_column = PgArray.columns_hash["ratings"]
    assert_equal :integer, ratings_column.type
    assert_predicate ratings_column, :array?
  end

  def test_not_compatible_with_serialize_array
    new_klass = Class.new(PgArray) do
      serialize :tags, Array
    end
    assert_raises(ActiveRecord::AttributeMethods::Serialization::ColumnNotSerializableError) do
      new_klass.new
    end
  end

  class MyTags
    def initialize(tags); @tags = tags end
    def to_a; @tags end
    def self.load(tags); new(tags) end
    def self.dump(object); object.to_a end
  end

  def test_array_with_serialized_attributes
    new_klass = Class.new(PgArray) do
      serialize :tags, MyTags
    end

    new_klass.create!(tags: MyTags.new(["one", "two"]))
    record = new_klass.first

    assert_instance_of MyTags, record.tags
    assert_equal ["one", "two"], record.tags.to_a

    record.tags = MyTags.new(["three", "four"])
    record.save!

    assert_equal ["three", "four"], record.reload.tags.to_a
  end

  def test_default
    @connection.add_column "pg_arrays", "score", :integer, array: true, default: [4, 4, 2]
    PgArray.reset_column_information

    assert_equal([4, 4, 2], PgArray.column_defaults["score"])
    assert_equal([4, 4, 2], PgArray.new.score)
  ensure
    PgArray.reset_column_information
  end

  def test_default_strings
    @connection.add_column "pg_arrays", "names", :string, array: true, default: ["foo", "bar"]
    PgArray.reset_column_information

    assert_equal(["foo", "bar"], PgArray.column_defaults["names"])
    assert_equal(["foo", "bar"], PgArray.new.names)
  ensure
    PgArray.reset_column_information
  end

  def test_change_column_with_array
    @connection.add_column :pg_arrays, :snippets, :string, array: true, default: []
    @connection.change_column :pg_arrays, :snippets, :text, array: true, default: []

    PgArray.reset_column_information
    column = PgArray.columns_hash["snippets"]

    assert_equal :text, column.type
    assert_equal [], PgArray.column_defaults["snippets"]
    assert_predicate column, :array?
  end

  def test_change_column_from_non_array_to_array
    @connection.add_column :pg_arrays, :snippets, :string
    @connection.change_column :pg_arrays, :snippets, :text, array: true, default: [], using: "string_to_array(\"snippets\", ',')"

    PgArray.reset_column_information
    column = PgArray.columns_hash["snippets"]

    assert_equal :text, column.type
    assert_equal [], PgArray.column_defaults["snippets"]
    assert_predicate column, :array?
  end

  def test_change_column_cant_make_non_array_column_to_array
    @connection.add_column :pg_arrays, :a_string, :string
    assert_raises ActiveRecord::StatementInvalid do
      @connection.transaction do
        @connection.change_column :pg_arrays, :a_string, :string, array: true
      end
    end
  end

  def test_change_column_default_with_array
    @connection.change_column_default :pg_arrays, :tags, []

    PgArray.reset_column_information
    assert_equal [], PgArray.column_defaults["tags"]
  end

  def test_type_cast_array
    assert_equal(["1", "2", "3"], @type.deserialize("{1,2,3}"))
    assert_equal([], @type.deserialize("{}"))
    assert_equal([nil], @type.deserialize("{NULL}"))
  end

  def test_type_cast_integers
    x = PgArray.new(ratings: ["1", "2"])

    assert_equal([1, 2], x.ratings)

    x.save!
    x.reload

    assert_equal([1, 2], x.ratings)
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema "pg_arrays"
    assert_match %r[t\.string\s+"tags",\s+limit: 255,\s+array: true], output
    assert_match %r[t\.integer\s+"ratings",\s+array: true], output
    assert_match %r[t\.decimal\s+"decimals",\s+precision: 10,\s+scale: 2,\s+default: \[\],\s+array: true], output
  end

  def test_select_with_strings
    @connection.execute "insert into pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    assert_equal(["1", "2", "3"], x.tags)
  end

  def test_rewrite_with_strings
    @connection.execute "insert into pg_arrays (tags) VALUES ('{1,2,3}')"
    x = PgArray.first
    x.tags = ["1", "2", "3", "4"]
    x.save!
    assert_equal ["1", "2", "3", "4"], x.reload.tags
  end

  def test_select_with_integers
    @connection.execute "insert into pg_arrays (ratings) VALUES ('{1,2,3}')"
    x = PgArray.first
    assert_equal([1, 2, 3], x.ratings)
  end

  def test_rewrite_with_integers
    @connection.execute "insert into pg_arrays (ratings) VALUES ('{1,2,3}')"
    x = PgArray.first
    x.ratings = [2, "3", 4]
    x.save!
    assert_equal [2, 3, 4], x.reload.ratings
  end

  def test_multi_dimensional_with_strings
    assert_cycle(:tags, [[["1"], ["2"]], [["2"], ["3"]]])
  end

  def test_with_empty_strings
    assert_cycle(:tags, [ "1", "2", "", "4", "", "5" ])
  end

  def test_with_multi_dimensional_empty_strings
    assert_cycle(:tags, [[["1", "2"], ["", "4"], ["", "5"]]])
  end

  def test_with_arbitrary_whitespace
    assert_cycle(:tags, [[["1", "2"], ["    ", "4"], ["    ", "5"]]])
  end

  def test_multi_dimensional_with_integers
    assert_cycle(:ratings, [[[1], [7]], [[8], [10]]])
  end

  def test_strings_with_quotes
    assert_cycle(:tags, ["this has", 'some "s that need to be escaped"'])
  end

  def test_strings_with_commas
    assert_cycle(:tags, ["this,has", "many,values"])
  end

  def test_strings_with_array_delimiters
    assert_cycle(:tags, ["{", "}"])
  end

  def test_strings_with_null_strings
    assert_cycle(:tags, ["NULL", "NULL"])
  end

  def test_contains_nils
    assert_cycle(:tags, ["1", nil, nil])
  end

  def test_insert_fixture
    tag_values = ["val1", "val2", "val3_with_'_multiple_quote_'_chars"]
    @connection.insert_fixture({ "tags" => tag_values }, "pg_arrays")
    assert_equal(PgArray.last.tags, tag_values)
  end

  def test_attribute_for_inspect_for_array_field
    record = PgArray.new { |a| a.ratings = (1..10).to_a }
    assert_equal("[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]", record.attribute_for_inspect(:ratings))
  end

  def test_attribute_for_inspect_for_array_field_for_large_array
    record = PgArray.new { |a| a.ratings = (1..11).to_a }
    assert_equal("[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]", record.attribute_for_inspect(:ratings))
  end

  def test_escaping
    unknown = 'foo\\",bar,baz,\\'
    tags = ["hello_#{unknown}"]
    ar = PgArray.create!(tags: tags)
    ar.reload
    assert_equal tags, ar.tags
  end

  def test_string_quoting_rules_match_pg_behavior
    tags = ["", "one{", "two}", %(three"), "four\\", "five ", "six\t", "seven\n", "eight,", "nine", "ten\r", "NULL"]
    x = PgArray.create!(tags: tags)
    x.reload

    assert_not_predicate x, :changed?
  end

  def test_quoting_non_standard_delimiters
    strings = ["hello,", "world;"]
    oid = ActiveRecord::ConnectionAdapters::PostgreSQL::OID
    comma_delim = oid::Array.new(ActiveRecord::Type::String.new, ",")
    semicolon_delim = oid::Array.new(ActiveRecord::Type::String.new, ";")
    conn = PgArray.connection

    assert_equal %({"hello,",world;}), conn.type_cast(comma_delim.serialize(strings))
    assert_equal %({hello,;"world;"}), conn.type_cast(semicolon_delim.serialize(strings))
  end

  def test_mutate_array
    x = PgArray.create!(tags: %w(one two))

    x.tags << "three"
    x.save!
    x.reload

    assert_equal %w(one two three), x.tags
    assert_not_predicate x, :changed?
  end

  def test_mutate_value_in_array
    x = PgArray.create!(hstores: [{ a: "a" }, { b: "b" }])

    x.hstores.first["a"] = "c"
    x.save!
    x.reload

    assert_equal [{ "a" => "c" }, { "b" => "b" }], x.hstores
    assert_not_predicate x, :changed?
  end

  def test_datetime_with_timezone_awareness
    tz = "Pacific Time (US & Canada)"

    in_time_zone tz do
      PgArray.reset_column_information
      time_string = Time.current.to_s
      time = Time.zone.parse(time_string)

      record = PgArray.new(datetimes: [time_string])
      assert_equal [time], record.datetimes
      assert_equal ActiveSupport::TimeZone[tz], record.datetimes.first.time_zone

      record.save!
      record.reload

      assert_equal [time], record.datetimes
      assert_equal ActiveSupport::TimeZone[tz], record.datetimes.first.time_zone
    end
  end

  def test_assigning_non_array_value
    record = PgArray.new(tags: "not-an-array")
    assert_equal [], record.tags
    assert_equal "not-an-array", record.tags_before_type_cast
    assert record.save
    assert_equal record.tags, record.reload.tags
  end

  def test_assigning_empty_string
    record = PgArray.new(tags: "")
    assert_equal [], record.tags
    assert_equal "", record.tags_before_type_cast
    assert record.save
    assert_equal record.tags, record.reload.tags
  end

  def test_assigning_valid_pg_array_literal
    record = PgArray.new(tags: "{1,2,3}")
    assert_equal ["1", "2", "3"], record.tags
    assert_equal "{1,2,3}", record.tags_before_type_cast
    assert record.save
    assert_equal record.tags, record.reload.tags
  end

  def test_where_by_attribute_with_array
    tags = ["black", "blue"]
    record = PgArray.create!(tags: tags)
    assert_equal record, PgArray.where(tags: tags).take
  end

  def test_uniqueness_validation
    klass = Class.new(PgArray) do
      validates_uniqueness_of :tags

      def self.model_name; ActiveModel::Name.new(PgArray) end
    end
    e1 = klass.create("tags" => ["black", "blue"])
    assert e1.persisted?, "Saving e1"

    e2 = klass.create("tags" => ["black", "blue"])
    assert_not e2.persisted?, "e2 shouldn't be valid"
    assert e2.errors[:tags].any?, "Should have errors for tags"
    assert_equal ["has already been taken"], e2.errors[:tags], "Should have uniqueness message for tags"
  end

  def test_encoding_arrays_of_utf8_strings
    arrays_of_utf8_strings = %w(nový ファイル)
    assert_equal arrays_of_utf8_strings, @type.deserialize(@type.serialize(arrays_of_utf8_strings))
    assert_equal [arrays_of_utf8_strings], @type.deserialize(@type.serialize([arrays_of_utf8_strings]))
  end

  def test_precision_is_respected_on_timestamp_columns
    time = Time.now.change(usec: 123)
    record = PgArray.create!(timestamps: [time])

    assert_equal 123, record.timestamps.first.usec
    record.reload
    assert_equal 123, record.timestamps.first.usec
  end

  def test_binary_arrays_are_serialized_correctly
    signatures = ["signature1", "signature2"]
    PgArray.create!(signatures: signatures)

    assert_equal signatures, PgArray.last.signatures
    assert_equal 1, PgArray.where(":signature = ANY(signatures)", signature: "signature1").count
  end

  private
    def assert_cycle(field, array)
      # test creation
      x = PgArray.create!(field => array)
      x.reload
      assert_equal(array, x.public_send(field))

      # test updating
      x = PgArray.create!(field => [])
      x.public_send("#{field}=", array)
      x.save!
      x.reload
      assert_equal(array, x.public_send(field))
    end
end
