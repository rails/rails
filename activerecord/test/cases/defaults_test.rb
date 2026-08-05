# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"
require "models/default"
require "models/entrant"

class DefaultTest < ActiveRecord::TestCase
  def test_nil_defaults_for_not_null_columns
    %w(id name course_id).each do |name|
      column = Entrant.columns_hash[name]
      assert_not column.null, "#{name} column should be NOT NULL"
      assert_not column.default, "#{name} column should be DEFAULT 'nil'"
    end
  end

  if current_adapter?(:PostgreSQLAdapter) || current_adapter?(:SQLite3Adapter)
    def test_multiline_default_text
      record = Default.new
      # older PostgreSQL versions represent the default with escapes ("\\012" for a newline)
      assert("--- []\n\n" == record.multiline_default || "--- []\\012\\012" == record.multiline_default)
    end
  end
end

class DefaultNumbersTest < ActiveRecord::TestCase
  class DefaultNumber < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :default_numbers do |t|
      t.integer :positive_integer, default: 7
      t.integer :negative_integer, default: -5
      t.decimal :decimal_number, default: "2.78", precision: 5, scale: 2
    end
  end

  teardown do
    @connection.drop_table :default_numbers, if_exists: true
  end

  def test_default_positive_integer
    record = DefaultNumber.new
    assert_equal 7, record.positive_integer
    assert_equal 7, record.positive_integer_before_type_cast
  end

  def test_default_negative_integer
    record = DefaultNumber.new
    assert_equal (-5), record.negative_integer
    assert_equal (-5), record.negative_integer_before_type_cast
  end

  def test_default_decimal_number
    record = DefaultNumber.new
    assert_equal BigDecimal("2.78"), record.decimal_number
    assert_equal BigDecimal("2.78"), record.decimal_number_before_type_cast
  end
end

class DefaultsWithOverriddenAttributeTypeTest < ActiveRecord::TestCase
  # A custom type is expected to receive the raw value from the database, so it
  # can be used to assert what the default is deserialized from.
  class RawValueType < ActiveModel::Type::Value
    def deserialize(value)
      value.class.name
    end
  end

  class StringNumber < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :number, :string
  end

  class RawNumber < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :number, RawValueType.new
  end

  class DatetimePublishedOn < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :published_on, :datetime
  end

  class RawPrice < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :price, RawValueType.new
  end

  class IntegerFlag < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :flag, :integer
  end

  class StringFlag < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :flag, :string
  end

  class IntegerFlagWithDefault < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    attribute :flag, :integer, default: 3
  end

  class NumberEnum < ActiveRecord::Base
    self.table_name = "overridden_defaults"
    enum :number, { seven: 7, eight: 8 }
  end

  class PlainDefaults < ActiveRecord::Base
    self.table_name = "overridden_defaults"
  end

  MODELS = [StringNumber, RawNumber, DatetimePublishedOn, RawPrice, IntegerFlag,
            StringFlag, IntegerFlagWithDefault, NumberEnum, PlainDefaults].freeze

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :overridden_defaults, force: true do |t|
      t.integer :number, default: 7
      t.boolean :flag, default: true
      t.date :published_on, default: "2020-01-02"
      t.decimal :price, default: 1.5, precision: 8, scale: 2
    end
    MODELS.each(&:reset_column_information)
  end

  teardown do
    @connection.drop_table :overridden_defaults, if_exists: true
  end

  def test_default_is_deserialized_with_the_overridden_type
    record = StringNumber.new
    assert_equal "7", record.number
    assert_equal "7", record.number_before_type_cast
  end

  def test_overridden_type_receives_the_raw_default
    assert_equal "String", RawNumber.new.number
    assert_equal "String", RawPrice.new.price
  end

  def test_mutable_overridden_type_deserializes_the_raw_default
    published_on = DatetimePublishedOn.new.published_on
    assert_kind_of Time, published_on
    assert_equal [2020, 1, 2], [published_on.year, published_on.month, published_on.day]
  end

  # Deserializing the default with the overridden type must not change anything
  # for the columns whose type is not overridden.
  def test_defaults_of_columns_that_are_not_overridden_are_unaffected
    record = PlainDefaults.new

    assert_equal 7, record.number
    assert_equal 7, record.number_before_type_cast
    assert_equal Date.new(2020, 1, 2), record.published_on
    assert_equal BigDecimal("1.5"), record.price
    assert_equal BigDecimal("1.5"), record.price_before_type_cast
  end

  # The column type deserializes the default into `true`, which an integer type
  # cannot deserialize. The overridden type has to be given the raw default.
  def test_overriding_the_type_of_a_column_the_default_is_not_valid_for
    assert_kind_of Integer, IntegerFlag.new.flag
  end

  if current_adapter?(:SQLite3Adapter)
    def test_sqlite_boolean_default_is_deserialized_with_the_overridden_type
      assert_equal 1, IntegerFlag.new.flag
      assert_equal "1", StringFlag.new.flag
    end
  end

  def test_overridden_type_is_used_to_round_trip_values
    record = StringNumber.create!(number: "9")
    assert_equal "9", record.reload.number
  end

  def test_partial_inserts_with_an_overridden_type
    original_partial_inserts = IntegerFlag.partial_inserts?
    IntegerFlag.partial_inserts = true

    record = IntegerFlag.create!(flag: 2)
    assert_equal 2, record.reload.flag
  ensure
    IntegerFlag.partial_inserts = original_partial_inserts
  end

  def test_overridden_type_with_a_user_provided_default
    assert_equal 3, IntegerFlagWithDefault.new.flag
    assert_equal 3, IntegerFlagWithDefault.create!.reload.flag
  end

  # `enum` overrides the type of the column it is declared on, so a column with
  # a default reaches the same code path as an explicit `attribute` override.
  def test_enum_on_a_column_with_a_default
    assert_equal "seven", NumberEnum.new.number
    assert_equal "seven", NumberEnum.create!.reload.number
  end

  def test_column_keeps_the_default_before_type_cast
    column = PlainDefaults.columns_hash["number"]

    assert_equal 7, column.default
    assert_equal "7", column.default_before_type_cast
  end

  def test_column_default_before_type_cast_survives_serialization
    column = YAML.unsafe_load(YAML.dump(StringNumber.columns_hash["number"]))

    assert_equal 7, column.default
    assert_equal "7", column.default_before_type_cast
  end

  def test_column_default_before_type_cast_falls_back_for_an_older_schema_cache
    column = ActiveRecord::ConnectionAdapters::Column.allocate
    column.init_with("name" => "number", "cast_type" => ActiveRecord::Type::Integer.new, "default" => 7)

    assert_equal 7, column.default_before_type_cast
  end

  def test_column_default_before_type_cast_falls_back_for_an_older_marshal_schema_cache
    column = StringNumber.columns_hash["number"].dup
    column.remove_instance_variable(:@default_before_type_cast)
    column = Marshal.load(Marshal.dump(column))

    assert_equal column.default, column.default_before_type_cast
  end
end

class DefaultStringsTest < ActiveRecord::TestCase
  class DefaultString < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :default_strings do |t|
      t.string :string_col, default: "Smith"
      t.string :string_col_with_quotes, default: "O'Connor"
    end
    DefaultString.reset_column_information
  end

  def test_default_strings
    assert_equal "Smith", DefaultString.new.string_col
  end

  def test_default_strings_containing_single_quotes
    assert_equal "O'Connor", DefaultString.new.string_col_with_quotes
  end

  teardown do
    @connection.drop_table :default_strings
  end
end

class DefaultBinaryTest < ActiveRecord::TestCase
  if current_adapter?(:SQLite3Adapter, :PostgreSQLAdapter)
    class DefaultBinary < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :default_binaries do |t|
        t.binary :varbinary_col, null: false, limit: 64, default: "varbinary_default"
        t.binary :varbinary_col_hex_looking, null: false, limit: 64, default: "0xDEADBEEF"
      end
      DefaultBinary.reset_column_information
    end

    def test_default_varbinary_string
      assert_equal "varbinary_default", DefaultBinary.new.varbinary_col
    end

    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter) && !ActiveRecord::Base.lease_connection.mariadb?
      def test_default_binary_string
        assert_equal "binary_default", DefaultBinary.new.binary_col
      end
    end

    def test_default_varbinary_string_that_looks_like_hex
      assert_equal "0xDEADBEEF", DefaultBinary.new.varbinary_col_hex_looking
    end

    teardown do
      @connection.drop_table :default_binaries
    end
  end
end

class DefaultTextTest < ActiveRecord::TestCase
  if supports_text_column_with_default?
    class DefaultText < ActiveRecord::Base; end

    setup do
      @connection = ActiveRecord::Base.lease_connection
      @connection.create_table :default_texts do |t|
        t.text :text_col, default: "Smith"
        t.text :text_col_with_quotes, default: "O'Connor"
      end
      DefaultText.reset_column_information
    end

    def test_default_texts
      assert_equal "Smith", DefaultText.new.text_col
    end

    def test_default_texts_containing_single_quotes
      assert_equal "O'Connor", DefaultText.new.text_col_with_quotes
    end

    teardown do
      @connection.drop_table :default_texts
    end
  end
end

class PostgresqlDefaultExpressionTest < ActiveRecord::TestCase
  if current_adapter?(:PostgreSQLAdapter)
    include SchemaDumpingHelper

    test "schema dump includes default expression" do
      output = dump_table_schema("defaults")
      if ActiveRecord::Base.lease_connection.database_version >= 100000
        assert_match %r/t\.date\s+"modified_date",\s+default: -> { "CURRENT_DATE" }/, output
        assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "CURRENT_TIMESTAMP" }/, output
        assert_match %r/t\.datetime\s+"modified_time_without_precision",\s+default: -> { "CURRENT_TIMESTAMP" }/, output
        assert_match %r/t\.datetime\s+"modified_time_with_precision_0",\s+precision: 0,\s+default: -> { "CURRENT_TIMESTAMP" }/, output
      else
        assert_match %r/t\.date\s+"modified_date",\s+default: -> { "\('now'::text\)::date" }/, output
        assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "now\(\)" }/, output
        assert_match %r/t\.datetime\s+"modified_time_without_precision",\s+default: -> { "now\(\)" }/, output
        assert_match %r/t\.datetime\s+"modified_time_with_precision_0",\s+precision: 0,\s+default: -> { "now\(\)" }/, output
      end
      assert_match %r/t\.date\s+"modified_date_function",\s+default: -> { "now\(\)" }/, output
      assert_match %r/t\.datetime\s+"modified_time_function",\s+default: -> { "now\(\)" }/, output
    end
  end
end

class MysqlDefaultExpressionTest < ActiveRecord::TestCase
  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    include SchemaDumpingHelper

    if supports_default_expression?
      test "schema dump includes default expression" do
        output = dump_table_schema("defaults")
        assert_match %r/t\.binary\s+"uuid",\s+limit: 36,\s+default: -> { "\(?uuid\(\)\)?" }/i, output
      end

      test "schema dump includes default expression with single quotes reflected correctly" do
        output = dump_table_schema("defaults")
        assert_match %r/t\.string\s+"char2_concatenated",\s+default: -> { "\(?concat\(`char2`,(_utf8mb4)?'-'\)\)?" }/i, output
      end
    end

    test "schema dump datetime includes default expression" do
      output = dump_table_schema("datetime_defaults")
      assert_match %r/t\.datetime\s+"modified_datetime",\s+precision: nil,\s+default: -> { "CURRENT_TIMESTAMP(?:\(\))?" }/i, output
    end

    test "schema dump datetime includes precise default expression" do
      output = dump_table_schema("datetime_defaults")
      assert_match %r/t\.datetime\s+"precise_datetime",\s+default: -> { "CURRENT_TIMESTAMP\(6\)" }/i, output
    end

    test "schema dump datetime includes precise default expression with on update" do
      output = dump_table_schema("datetime_defaults")
      assert_match %r/t\.datetime\s+"updated_datetime",\s+default: -> { "CURRENT_TIMESTAMP\(6\) ON UPDATE CURRENT_TIMESTAMP\(6\)" }/i, output
    end

    test "schema dump timestamp includes default expression" do
      output = dump_table_schema("timestamp_defaults")
      assert_match %r/t\.timestamp\s+"modified_timestamp",\s+default: -> { "CURRENT_TIMESTAMP(?:\(\))?" }/i, output
    end

    test "schema dump timestamp includes precise default expression" do
      output = dump_table_schema("timestamp_defaults")
      assert_match %r/t\.timestamp\s+"precise_timestamp",.+default: -> { "CURRENT_TIMESTAMP\(6\)" }/i, output
    end

    test "schema dump timestamp includes precise default expression with on update" do
      output = dump_table_schema("timestamp_defaults")
      assert_match %r/t\.timestamp\s+"updated_timestamp",.+default: -> { "CURRENT_TIMESTAMP\(6\) ON UPDATE CURRENT_TIMESTAMP\(6\)" }/i, output
    end

    test "schema dump timestamp without default expression" do
      output = dump_table_schema("timestamp_defaults")
      assert_match %r/t\.timestamp\s+"nullable_timestamp"$/, output
    end
  end
end

class DefaultsTestWithoutTransactionalFixtures < ActiveRecord::TestCase
  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    # ActiveRecord::Base#create! (and #save and other related methods) will
    # open a new transaction. When in transactional tests mode, this will
    # cause Active Record to create a new savepoint. However, since MySQL doesn't
    # support DDL transactions, creating a table will result in any created
    # savepoints to be automatically released. This in turn causes the savepoint
    # release code in AbstractAdapter#transaction to fail.
    #
    # We don't want that to happen, so we disable transactional tests here.
    self.use_transactional_tests = false

    def using_strict(strict)
      db_config = ActiveRecord::Base.connection_pool.db_config
      conn_hash = db_config.configuration_hash
      ActiveRecord.deprecator.silence do
        ActiveRecord::Base.establish_connection conn_hash.merge(strict: strict)
        yield
      end
    ensure
      ActiveRecord::Base.establish_connection db_config
    end

    # Strict mode controls how MySQL handles invalid or missing values
    # in data-change statements such as INSERT or UPDATE. A value can be
    # invalid for several reasons. For example, it might have the wrong
    # data type for the column, or it might be out of range. A value is
    # missing when a new row to be inserted does not contain a value for
    # a non-NULL column that has no explicit DEFAULT clause in its definition.
    # (For a NULL column, NULL is inserted if the value is missing.)
    #
    # If strict mode is not in effect, MySQL inserts adjusted values for
    # invalid or missing values and produces warnings. In strict mode,
    # you can produce this behavior by using INSERT IGNORE or UPDATE IGNORE.
    #
    # https://dev.mysql.com/doc/refman/en/sql-mode.html#sql-mode-strict
    def test_mysql_not_null_defaults_non_strict
      using_strict(false) do
        with_mysql_not_null_table do |klass|
          record = klass.new
          assert_nil record.non_null_integer
          assert_nil record.non_null_string
          assert_nil record.non_null_text
          assert_nil record.non_null_blob

          record.save!
          record.reload

          assert_equal 0,  record.non_null_integer
          assert_equal "", record.non_null_string
          assert_equal "", record.non_null_text
          assert_equal "", record.non_null_blob
        end
      end
    end

    def test_mysql_not_null_defaults_strict
      using_strict(true) do
        with_mysql_not_null_table do |klass|
          record = klass.new
          assert_nil record.non_null_integer
          assert_nil record.non_null_string
          assert_nil record.non_null_text
          assert_nil record.non_null_blob

          assert_raises(ActiveRecord::NotNullViolation) { klass.create }
        end
      end
    end

    def with_mysql_not_null_table
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = "test_mysql_not_null_defaults"
      klass.lease_connection.create_table klass.table_name do |t|
        t.integer :non_null_integer, null: false
        t.string  :non_null_string,  null: false
        t.text    :non_null_text,    null: false
        t.blob    :non_null_blob,    null: false
      end

      yield klass
    ensure
      klass.lease_connection.drop_table(klass.table_name) rescue nil
    end
  end
end

class Sqlite3DefaultExpressionTest < ActiveRecord::TestCase
  if current_adapter?(:SQLite3Adapter)
    include SchemaDumpingHelper

    test "schema dump includes default expression" do
      output = dump_table_schema("defaults")
      assert_match %r/t\.date\s+"modified_date",\s+default: -> { "CURRENT_DATE" }/, output
      assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "CURRENT_TIMESTAMP" }/, output
      assert_match %r/t\.datetime\s+"modified_time_without_precision",\s+precision: nil,\s+default: -> { "CURRENT_TIMESTAMP" }/, output
      assert_match %r/t\.datetime\s+"modified_time_with_precision_0",\s+precision: 0,\s+default: -> { "CURRENT_TIMESTAMP" }/, output
      assert_match %r/t\.integer\s+"random_number",\s+default: -> { "ABS\(RANDOM\(\) % 100\)" }/, output
    end
  end
end
