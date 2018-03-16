# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class SchemaDumperTest < ActiveRecord::TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  setup do
    ActiveRecord::SchemaMigration.create_table
  end

  def standard_dump
    @@standard_dump ||= perform_schema_dump
  end

  def perform_schema_dump
    dump_all_table_schema []
  end

  def test_dump_schema_information_with_empty_versions
    ActiveRecord::SchemaMigration.delete_all
    schema_info = ActiveRecord::Base.connection.dump_schema_information
    assert_no_match(/INSERT INTO/, schema_info)
  end

  def test_dump_schema_information_outputs_lexically_ordered_versions
    versions = %w{ 20100101010101 20100201010101 20100301010101 }
    versions.reverse_each do |v|
      ActiveRecord::SchemaMigration.create!(version: v)
    end

    schema_info = ActiveRecord::Base.connection.dump_schema_information
    assert_match(/20100201010101.*20100301010101/m, schema_info)
  ensure
    ActiveRecord::SchemaMigration.delete_all
  end

  if current_adapter?(:SQLite3Adapter)
    %w{3.7.8 3.7.11 3.7.12}.each do |version_string|
      test "dumps schema version for sqlite version #{version_string}" do
        version = ActiveRecord::ConnectionAdapters::SQLite3Adapter::Version.new(version_string)
        ActiveRecord::Base.connection.stubs(:sqlite_version).returns(version)

        versions = %w{ 20100101010101 20100201010101 20100301010101 }
        versions.reverse_each do |v|
          ActiveRecord::SchemaMigration.create!(version: v)
        end

        schema_info = ActiveRecord::Base.connection.dump_schema_information
        assert_match(/20100201010101.*20100301010101/m, schema_info)
        ActiveRecord::SchemaMigration.delete_all
      end
    end
  end

  def test_schema_dump
    output = standard_dump
    assert_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{(?<=, ) do \|t\|}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output
  end

  def test_schema_dump_uses_force_cascade_on_create_table
    output = dump_table_schema "authors"
    assert_match %r{create_table "authors",.* force: :cascade}, output
  end

  def test_schema_dump_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

  def test_schema_dump_includes_camelcase_table_name
    output = standard_dump
    assert_match %r{create_table "CamelCase"}, output
  end

  def assert_no_line_up(lines, pattern)
    return assert(true) if lines.empty?
    matches = lines.map { |line| line.match(pattern) }
    matches.compact!
    return assert(true) if matches.empty?
    line_matches = lines.map { |line| [line, line.match(pattern)] }.select { |line, match| match }
    assert line_matches.all? { |line, match|
      start = match.offset(0).first
      line[start - 2..start - 1] == ", "
    }
  end

  def column_definition_lines(output = standard_dump)
    output.scan(/^( *)create_table.*?\n(.*?)^\1end/m).map { |m| m.last.split(/\n/) }
  end

  def test_types_no_line_up
    column_definition_lines.each do |column_set|
      next if column_set.empty?

      assert column_set.all? { |column| !column.match(/\bt\.\w+\s{2,}/) }
    end
  end

  def test_arguments_no_line_up
    column_definition_lines.each do |column_set|
      assert_no_line_up(column_set, /default: /)
      assert_no_line_up(column_set, /limit: /)
      assert_no_line_up(column_set, /null: /)
    end
  end

  def test_no_dump_errors
    output = standard_dump
    assert_no_match %r{\# Could not dump table}, output
  end

  def test_schema_dump_includes_not_null_columns
    output = dump_all_table_schema([/^[^r]/])
    assert_match %r{null: false}, output
  end

  def test_schema_dump_includes_limit_constraint_for_integer_columns
    output = dump_all_table_schema([/^(?!integer_limits)/])

    assert_match %r{"c_int_without_limit"(?!.*limit)}, output

    if current_adapter?(:PostgreSQLAdapter)
      assert_match %r{c_int_1.*limit: 2}, output
      assert_match %r{c_int_2.*limit: 2}, output

      # int 3 is 4 bytes in postgresql
      assert_match %r{"c_int_3"(?!.*limit)}, output
      assert_match %r{"c_int_4"(?!.*limit)}, output
    elsif current_adapter?(:Mysql2Adapter)
      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output

      assert_match %r{"c_int_4"(?!.*limit)}, output
    elsif current_adapter?(:SQLite3Adapter)
      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output
      assert_match %r{c_int_4.*limit: 4}, output
    end

    if current_adapter?(:SQLite3Adapter, :OracleAdapter)
      assert_match %r{c_int_5.*limit: 5}, output
      assert_match %r{c_int_6.*limit: 6}, output
      assert_match %r{c_int_7.*limit: 7}, output
      assert_match %r{c_int_8.*limit: 8}, output
    else
      assert_match %r{t\.bigint\s+"c_int_5"$}, output
      assert_match %r{t\.bigint\s+"c_int_6"$}, output
      assert_match %r{t\.bigint\s+"c_int_7"$}, output
      assert_match %r{t\.bigint\s+"c_int_8"$}, output
    end
  end

  def test_schema_dump_with_string_ignored_table
    output = dump_all_table_schema(["accounts"])
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    output = dump_all_table_schema([/^account/])
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output
  end

  def test_schema_dumps_index_columns_in_right_order
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_index/).first.strip
    if current_adapter?(:Mysql2Adapter)
      if ActiveRecord::Base.connection.supports_index_sort_order?
        assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", length: { type: 10 }, order: { rating: :desc }', index_definition
      else
        assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", length: { type: 10 }', index_definition
      end
    elsif ActiveRecord::Base.connection.supports_index_sort_order?
      assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", order: { rating: :desc }', index_definition
    else
      assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index"', index_definition
    end
  end

  def test_schema_dumps_partial_indices
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_partial_index/).first.strip
    if current_adapter?(:PostgreSQLAdapter, :SQLite3Adapter) && ActiveRecord::Base.connection.supports_partial_index?
      assert_equal 't.index ["firm_id", "type"], name: "company_partial_index", where: "(rating > 10)"', index_definition
    else
      assert_equal 't.index ["firm_id", "type"], name: "company_partial_index"', index_definition
    end
  end

  def test_schema_dumps_index_sort_order
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*_name_and_rating/).first.strip
    if ActiveRecord::Base.connection.supports_index_sort_order?
      assert_equal 't.index ["name", "rating"], name: "index_companies_on_name_and_rating", order: :desc', index_definition
    else
      assert_equal 't.index ["name", "rating"], name: "index_companies_on_name_and_rating"', index_definition
    end
  end

  def test_schema_dumps_index_length
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*_name_and_description/).first.strip
    if current_adapter?(:Mysql2Adapter)
      assert_equal 't.index ["name", "description"], name: "index_companies_on_name_and_description", length: 10', index_definition
    else
      assert_equal 't.index ["name", "description"], name: "index_companies_on_name_and_description"', index_definition
    end
  end

  def test_schema_dump_should_honor_nonstandard_primary_keys
    output = standard_dump
    match = output.match(%r{create_table "movies"(.*)do})
    assert_not_nil(match, "nonstandardpk table not found")
    assert_match %r(primary_key: "movieid"), match[1], "non-standard primary key not preserved"
  end

  def test_schema_dump_should_use_false_as_default
    output = dump_table_schema "booleans"
    assert_match %r{t\.boolean\s+"has_fun",.+default: false}, output
  end

  def test_schema_dump_does_not_include_limit_for_text_field
    output = dump_table_schema "admin_users"
    assert_match %r{t\.text\s+"params"$}, output
  end

  def test_schema_dump_does_not_include_limit_for_binary_field
    output = dump_table_schema "binaries"
    assert_match %r{t\.binary\s+"data"$}, output
  end

  def test_schema_dump_does_not_include_limit_for_float_field
    output = dump_table_schema "numeric_data"
    assert_match %r{t\.float\s+"temperature"$}, output
  end

  if current_adapter?(:Mysql2Adapter)
    def test_schema_dump_includes_length_for_mysql_binary_fields
      output = standard_dump
      assert_match %r{t\.binary\s+"var_binary",\s+limit: 255$}, output
      assert_match %r{t\.binary\s+"var_binary_large",\s+limit: 4095$}, output
    end

    def test_schema_dump_includes_length_for_mysql_blob_and_text_fields
      output = standard_dump
      assert_match %r{t\.blob\s+"tiny_blob",\s+limit: 255$}, output
      assert_match %r{t\.binary\s+"normal_blob"$}, output
      assert_match %r{t\.binary\s+"medium_blob",\s+limit: 16777215$}, output
      assert_match %r{t\.binary\s+"long_blob",\s+limit: 4294967295$}, output
      assert_match %r{t\.text\s+"tiny_text",\s+limit: 255$}, output
      assert_match %r{t\.text\s+"normal_text"$}, output
      assert_match %r{t\.text\s+"medium_text",\s+limit: 16777215$}, output
      assert_match %r{t\.text\s+"long_text",\s+limit: 4294967295$}, output
    end

    def test_schema_does_not_include_limit_for_emulated_mysql_boolean_fields
      output = standard_dump
      assert_no_match %r{t\.boolean\s+"has_fun",.+limit: 1}, output
    end

    def test_schema_dumps_index_type
      output = dump_table_schema "key_tests"
      assert_match %r{t\.index \["awesome"\], name: "index_key_tests_on_awesome", type: :fulltext$}, output
      assert_match %r{t\.index \["pizza"\], name: "index_key_tests_on_pizza"$}, output
    end
  end

  def test_schema_dump_includes_decimal_options
    output = dump_all_table_schema([/^[^n]/])
    assert_match %r{precision: 3,[[:space:]]+scale: 2,[[:space:]]+default: "2\.78"}, output
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_schema_dump_includes_bigint_default
      output = dump_table_schema "defaults"
      assert_match %r{t\.bigint\s+"bigint_default",\s+default: 0}, output
    end

    def test_schema_dump_includes_limit_on_array_type
      output = dump_table_schema "bigint_array"
      assert_match %r{t\.bigint\s+"big_int_data_points\",\s+array: true}, output
    end

    def test_schema_dump_allows_array_of_decimal_defaults
      output = dump_table_schema "bigint_array"
      assert_match %r{t\.decimal\s+"decimal_array_default",\s+default: \["1.23", "3.45"\],\s+array: true}, output
    end

    def test_schema_dump_expression_indices
      index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_expression_index/).first.strip
      assert_match %r{CASE.+lower\(\(name\)::text\)}i, index_definition
    end

    def test_schema_dump_interval_type
      output = dump_table_schema "postgresql_times"
      assert_match %r{t\.interval\s+"time_interval"$}, output
      assert_match %r{t\.interval\s+"scaled_time_interval",\s+precision: 6$}, output
    end

    def test_schema_dump_oid_type
      output = dump_table_schema "postgresql_oids"
      assert_match %r{t\.oid\s+"obj_id"$}, output
    end

    def test_schema_dump_includes_extensions
      connection = ActiveRecord::Base.connection

      connection.stubs(:extensions).returns(["hstore"])
      output = perform_schema_dump
      assert_match "# These are extensions that must be enabled", output
      assert_match %r{enable_extension "hstore"}, output

      connection.stubs(:extensions).returns([])
      output = perform_schema_dump
      assert_no_match "# These are extensions that must be enabled", output
      assert_no_match %r{enable_extension}, output
    end

    def test_schema_dump_includes_extensions_in_alphabetic_order
      connection = ActiveRecord::Base.connection

      connection.stubs(:extensions).returns(["hstore", "uuid-ossp", "xml2"])
      output = perform_schema_dump
      enabled_extensions = output.scan(%r{enable_extension "(.+)"}).flatten
      assert_equal ["hstore", "uuid-ossp", "xml2"], enabled_extensions

      connection.stubs(:extensions).returns(["uuid-ossp", "xml2", "hstore"])
      output = perform_schema_dump
      enabled_extensions = output.scan(%r{enable_extension "(.+)"}).flatten
      assert_equal ["hstore", "uuid-ossp", "xml2"], enabled_extensions
    end
  end

  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump
    # Oracle supports precision up to 38 and it identifies decimals with scale 0 as integers
    if current_adapter?(:OracleAdapter)
      assert_match %r{t\.integer\s+"atoms_in_universe",\s+precision: 38}, output
    elsif current_adapter?(:FbAdapter)
      assert_match %r{t\.integer\s+"atoms_in_universe",\s+precision: 18}, output
    else
      assert_match %r{t\.decimal\s+"atoms_in_universe",\s+precision: 55}, output
    end
  end

  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
    output = standard_dump
    match = output.match(%r{create_table "goofy_string_id"(.*)do.*\n(.*)\n})
    assert_not_nil(match, "goofy_string_id table not found")
    assert_match %r(id: false), match[1], "no table id not preserved"
    assert_match %r{t\.string\s+"id",.*?null: false$}, match[2], "non-primary key id column not preserved"
  end

  def test_schema_dump_keeps_id_false_when_id_is_false_and_unique_not_null_column_added
    output = standard_dump
    assert_match %r{create_table "string_key_objects", id: false}, output
  end

  if ActiveRecord::Base.connection.supports_foreign_keys?
    def test_foreign_keys_are_dumped_at_the_bottom_to_circumvent_dependency_issues
      output = standard_dump
      assert_match(/^\s+add_foreign_key "fk_test_has_fk"[^\n]+\n\s+add_foreign_key "lessons_students"/, output)
    end

    def test_do_not_dump_foreign_keys_for_ignored_tables
      output = dump_table_schema "authors"
      assert_equal ["authors"], output.scan(/^\s*add_foreign_key "([^"]+)".+$/).flatten
    end
  end

  class CreateDogMigration < ActiveRecord::Migration::Current
    def up
      create_table("dog_owners") do |t|
      end

      create_table("dogs") do |t|
        t.column :name, :string
        t.references :owner
        t.index [:name]
        t.foreign_key :dog_owners, column: "owner_id"
      end
    end
    def down
      drop_table("dogs")
      drop_table("dog_owners")
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = "foo_"
    ActiveRecord::Base.table_name_suffix = "_bar"

    migration = CreateDogMigration.new
    migration.migrate(:up)

    output = perform_schema_dump
    assert_no_match %r{create_table "foo_.+_bar"}, output
    assert_no_match %r{add_index "foo_.+_bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output

    if ActiveRecord::Base.connection.supports_foreign_keys?
      assert_no_match %r{add_foreign_key "foo_.+_bar"}, output
      assert_no_match %r{add_foreign_key "[^"]+", "foo_.+_bar"}, output
    end
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ""
    $stdout = original
  end

  def test_schema_dump_with_table_name_prefix_and_suffix_regexp_escape
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = "foo$"
    ActiveRecord::Base.table_name_suffix = "$bar"

    migration = CreateDogMigration.new
    migration.migrate(:up)

    output = perform_schema_dump
    assert_no_match %r{create_table "foo\$.+\$bar"}, output
    assert_no_match %r{add_index "foo\$.+\$bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output

    if ActiveRecord::Base.connection.supports_foreign_keys?
      assert_no_match %r{add_foreign_key "foo\$.+\$bar"}, output
      assert_no_match %r{add_foreign_key "[^"]+", "foo\$.+\$bar"}, output
    end
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ""
    $stdout = original
  end

  def test_schema_dump_with_table_name_prefix_and_ignoring_tables
    original, $stdout = $stdout, StringIO.new

    create_cat_migration = Class.new(ActiveRecord::Migration::Current) do
      def change
        create_table("cats") do |t|
        end
        create_table("omg_cats") do |t|
        end
      end
    end

    original_table_name_prefix = ActiveRecord::Base.table_name_prefix
    original_schema_dumper_ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
    ActiveRecord::Base.table_name_prefix = "omg_"
    ActiveRecord::SchemaDumper.ignore_tables = ["cats"]
    migration = create_cat_migration.new
    migration.migrate(:up)

    stream = StringIO.new
    output = ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream).string

    assert_match %r{create_table "omg_cats"}, output
    refute_match %r{create_table "cats"}, output
  ensure
    migration.migrate(:down)
    ActiveRecord::Base.table_name_prefix = original_table_name_prefix
    ActiveRecord::SchemaDumper.ignore_tables = original_schema_dumper_ignore_tables

    $stdout = original
  end
end

class SchemaDumperDefaultsTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :dump_defaults, force: true do |t|
      t.string   :string_with_default,   default: "Hello!"
      t.date     :date_with_default,     default: "2014-06-05"
      t.datetime :datetime_with_default, default: "2014-06-05 07:17:04"
      t.time     :time_with_default,     default: "07:17:04"
      t.decimal  :decimal_with_default,  default: "1234567890.0123456789", precision: 20, scale: 10
    end

    if current_adapter?(:PostgreSQLAdapter)
      @connection.create_table :infinity_defaults, force: true do |t|
        t.float    :float_with_inf_default,    default: Float::INFINITY
        t.float    :float_with_nan_default,    default: Float::NAN
      end
    end
  end

  teardown do
    @connection.drop_table "dump_defaults", if_exists: true
  end

  def test_schema_dump_defaults_with_universally_supported_types
    output = dump_table_schema("dump_defaults")

    assert_match %r{t\.string\s+"string_with_default",.*?default: "Hello!"}, output
    assert_match %r{t\.date\s+"date_with_default",\s+default: "2014-06-05"}, output
    assert_match %r{t\.datetime\s+"datetime_with_default",\s+default: "2014-06-05 07:17:04"}, output
    assert_match %r{t\.time\s+"time_with_default",\s+default: "2000-01-01 07:17:04"}, output
    assert_match %r{t\.decimal\s+"decimal_with_default",\s+precision: 20,\s+scale: 10,\s+default: "1234567890.0123456789"}, output
  end

  def test_schema_dump_with_float_column_infinity_default
    skip unless current_adapter?(:PostgreSQLAdapter)
    output = dump_table_schema("infinity_defaults")
    assert_match %r{t\.float\s+"float_with_inf_default",\s+default: ::Float::INFINITY}, output
    assert_match %r{t\.float\s+"float_with_nan_default",\s+default: ::Float::NAN}, output
  end
end
