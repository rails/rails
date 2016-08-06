require "cases/helper"
require "support/schema_dumping_helper"
require "models/default"
require "models/entrant"

class DefaultTest < ActiveRecord::TestCase
  def test_nil_defaults_for_not_null_columns
    %w(id name course_id).each do |name|
      column = Entrant.columns_hash[name]
      assert !column.null, "#{name} column should be NOT NULL"
      assert_not column.default, "#{name} column should be DEFAULT 'nil'"
    end
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_multiline_default_text
      record = Default.new
      # older postgres versions represent the default with escapes ("\\012" for a newline)
      assert("--- []\n\n" == record.multiline_default || "--- []\\012\\012" == record.multiline_default)
    end
  end
end

class DefaultNumbersTest < ActiveRecord::TestCase
  class DefaultNumber < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
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
    assert_equal "7", record.positive_integer_before_type_cast
  end

  def test_default_negative_integer
    record = DefaultNumber.new
    assert_equal (-5), record.negative_integer
    assert_equal "-5", record.negative_integer_before_type_cast
  end

  def test_default_decimal_number
    record = DefaultNumber.new
    assert_equal BigDecimal.new("2.78"), record.decimal_number
    assert_equal "2.78", record.decimal_number_before_type_cast
  end
end

class DefaultStringsTest < ActiveRecord::TestCase
  class DefaultString < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
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

if current_adapter?(:PostgreSQLAdapter)
  class PostgresqlDefaultExpressionTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    test "schema dump includes default expression" do
      output = dump_table_schema("defaults")
      assert_match %r/t\.date\s+"modified_date",\s+default: -> { "\('now'::text\)::date" }/, output
      assert_match %r/t\.date\s+"modified_date_function",\s+default: -> { "now\(\)" }/, output
      assert_match %r/t\.datetime\s+"modified_time",\s+default: -> { "now\(\)" }/, output
      assert_match %r/t\.datetime\s+"modified_time_function",\s+default: -> { "now\(\)" }/, output
    end
  end
end

if current_adapter?(:Mysql2Adapter)
  class MysqlDefaultExpressionTest < ActiveRecord::TestCase
    include SchemaDumpingHelper

    if ActiveRecord::Base.connection.version >= "5.6.0"
      test "schema dump includes default expression" do
        output = dump_table_schema("datetime_defaults")
        assert_match %r/t\.datetime\s+"modified_datetime",\s+default: -> { "CURRENT_TIMESTAMP" }/, output
      end
    end
  end

  class DefaultsTestWithoutTransactionalFixtures < ActiveRecord::TestCase
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
      connection = ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection connection.merge(strict: strict)
      yield
    ensure
      ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection connection
    end

    # MySQL cannot have defaults on text/blob columns. It reports the
    # default value as null.
    #
    # Despite this, in non-strict mode, MySQL will use an empty string
    # as the default value of the field, if no other value is
    # specified.
    #
    # Therefore, in non-strict mode, we want column.default to report
    # an empty string as its default, to be consistent with that.
    #
    # In strict mode, column.default should be nil.
    def test_mysql_text_not_null_defaults_non_strict
      using_strict(false) do
        with_text_blob_not_null_table do |klass|
          record = klass.new
          assert_equal "", record.non_null_blob
          assert_equal "", record.non_null_text

          assert_nil record.null_blob
          assert_nil record.null_text

          record.save!
          record.reload

          assert_equal "", record.non_null_text
          assert_equal "", record.non_null_blob

          assert_nil record.null_text
          assert_nil record.null_blob
        end
      end
    end

    def test_mysql_text_not_null_defaults_strict
      using_strict(true) do
        with_text_blob_not_null_table do |klass|
          record = klass.new
          assert_nil record.non_null_blob
          assert_nil record.non_null_text
          assert_nil record.null_blob
          assert_nil record.null_text

          assert_raises(ActiveRecord::StatementInvalid) { klass.create }
        end
      end
    end

    def with_text_blob_not_null_table
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = "test_mysql_text_not_null_defaults"
      klass.connection.create_table klass.table_name do |t|
        t.column :non_null_text, :text, :null => false
        t.column :non_null_blob, :blob, :null => false
        t.column :null_text, :text, :null => true
        t.column :null_blob, :blob, :null => true
      end

      yield klass
    ensure
      klass.connection.drop_table(klass.table_name) rescue nil
    end

    # MySQL uses an implicit default 0 rather than NULL unless in strict mode.
    # We use an implicit NULL so schema.rb is compatible with other databases.
    def test_mysql_integer_not_null_defaults
      klass = Class.new(ActiveRecord::Base)
      klass.table_name = "test_integer_not_null_default_zero"
      klass.connection.create_table klass.table_name do |t|
        t.column :zero, :integer, :null => false, :default => 0
        t.column :omit, :integer, :null => false
      end

      assert_equal "0", klass.columns_hash["zero"].default
      assert !klass.columns_hash["zero"].null
      assert_equal nil, klass.columns_hash["omit"].default
      assert !klass.columns_hash["omit"].null

      assert_raise(ActiveRecord::StatementInvalid) { klass.create! }

      assert_nothing_raised do
        instance = klass.create!(:omit => 1)
        assert_equal 0, instance.zero
        assert_equal 1, instance.omit
      end
    ensure
      klass.connection.drop_table(klass.table_name) rescue nil
    end
  end
end
