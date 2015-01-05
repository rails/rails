require "cases/helper"
require 'support/schema_dumping_helper'

class SchemaDumperTest < ActiveRecord::TestCase
  include SchemaDumpingHelper
  self.use_transactional_fixtures = false

  setup do
    ActiveRecord::SchemaMigration.create_table
  end

  def standard_dump
    @@standard_dump ||= perform_schema_dump
  end

  def perform_schema_dump
    dump_all_table_schema []
  end

  def test_dump_schema_information_outputs_lexically_ordered_versions
    versions = %w{ 20100101010101 20100201010101 20100301010101 }
    versions.reverse_each do |v|
      ActiveRecord::SchemaMigration.create!(:version => v)
    end

    schema_info = ActiveRecord::Base.connection.dump_schema_information
    assert_match(/20100201010101.*20100301010101/m, schema_info)
  ensure
    ActiveRecord::SchemaMigration.delete_all
  end

  def test_magic_comment
    assert_match "# encoding: #{Encoding.default_external.name}", standard_dump
  end

  def test_schema_dump
    output = standard_dump
    assert_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_uses_force_cascade_on_create_table
    output = dump_table_schema "authors"
    assert_match %r{create_table "authors", force: :cascade}, output
  end

  def test_schema_dump_excludes_sqlite_sequence
    output = standard_dump
    assert_no_match %r{create_table "sqlite_sequence"}, output
  end

  def test_schema_dump_includes_camelcase_table_name
    output = standard_dump
    assert_match %r{create_table "CamelCase"}, output
  end

  def assert_line_up(lines, pattern, required = false)
    return assert(true) if lines.empty?
    matches = lines.map { |line| line.match(pattern) }
    assert matches.all? if required
    matches.compact!
    return assert(true) if matches.empty?
    assert_equal 1, matches.map{ |match| match.offset(0).first }.uniq.length
  end

  def column_definition_lines(output = standard_dump)
    output.scan(/^( *)create_table.*?\n(.*?)^\1end/m).map{ |m| m.last.split(/\n/) }
  end

  def test_types_line_up
    column_definition_lines.each do |column_set|
      next if column_set.empty?

      lengths = column_set.map do |column|
        if match = column.match(/t\.(?:integer|decimal|float|datetime|timestamp|time|date|text|binary|string|boolean|uuid|point)\s+"/)
          match[0].length
        end
      end

      assert_equal 1, lengths.uniq.length
    end
  end

  def test_arguments_line_up
    column_definition_lines.each do |column_set|
      assert_line_up(column_set, /default: /)
      assert_line_up(column_set, /limit: /)
      assert_line_up(column_set, /null: /)
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

    assert_match %r{c_int_without_limit}, output

    if current_adapter?(:PostgreSQLAdapter)
      assert_no_match %r{c_int_without_limit.*limit:}, output

      assert_match %r{c_int_1.*limit: 2}, output
      assert_match %r{c_int_2.*limit: 2}, output

      # int 3 is 4 bytes in postgresql
      assert_match %r{c_int_3.*}, output
      assert_no_match %r{c_int_3.*limit:}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*limit:}, output
    elsif current_adapter?(:MysqlAdapter, :Mysql2Adapter)
      assert_match %r{c_int_without_limit.*limit: 4}, output

      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*:limit}, output
    elsif current_adapter?(:SQLite3Adapter)
      assert_no_match %r{c_int_without_limit.*limit:}, output

      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output
      assert_match %r{c_int_4.*limit: 4}, output
    end

    if current_adapter?(:SQLite3Adapter)
      assert_match %r{c_int_5.*limit: 5}, output
      assert_match %r{c_int_6.*limit: 6}, output
      assert_match %r{c_int_7.*limit: 7}, output
      assert_match %r{c_int_8.*limit: 8}, output
    elsif current_adapter?(:OracleAdapter)
      assert_match %r{c_int_5.*limit: 5}, output
      assert_match %r{c_int_6.*limit: 6}, output
      assert_match %r{c_int_7.*limit: 7}, output
      assert_match %r{c_int_8.*limit: 8}, output
    else
      assert_match %r{c_int_5.*limit: 8}, output
      assert_match %r{c_int_6.*limit: 8}, output
      assert_match %r{c_int_7.*limit: 8}, output
      assert_match %r{c_int_8.*limit: 8}, output
    end
  end

  def test_schema_dump_with_string_ignored_table
    output = dump_all_table_schema(['accounts'])
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    output = dump_all_table_schema([/^account/])
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dumps_index_columns_in_right_order
    index_definition = standard_dump.split(/\n/).grep(/add_index.*companies/).first.strip
    if current_adapter?(:MysqlAdapter, :Mysql2Adapter, :PostgreSQLAdapter)
      assert_equal 'add_index "companies", ["firm_id", "type", "rating"], name: "company_index", using: :btree', index_definition
    else
      assert_equal 'add_index "companies", ["firm_id", "type", "rating"], name: "company_index"', index_definition
    end
  end

  def test_schema_dumps_partial_indices
    index_definition = standard_dump.split(/\n/).grep(/add_index.*company_partial_index/).first.strip
    if current_adapter?(:PostgreSQLAdapter)
      assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index", where: "(rating > 10)", using: :btree', index_definition
    elsif current_adapter?(:MysqlAdapter, :Mysql2Adapter)
      assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index", using: :btree', index_definition
    elsif current_adapter?(:SQLite3Adapter) && ActiveRecord::Base.connection.supports_partial_index?
      assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index", where: "rating > 10"', index_definition
    else
      assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index"', index_definition
    end
  end

  def test_schema_dump_should_honor_nonstandard_primary_keys
    output = standard_dump
    match = output.match(%r{create_table "movies"(.*)do})
    assert_not_nil(match, "nonstandardpk table not found")
    assert_match %r(primary_key: "movieid"), match[1], "non-standard primary key not preserved"
  end

  def test_schema_dump_should_use_false_as_default
    output = standard_dump
    assert_match %r{t\.boolean\s+"has_fun",.+default: false}, output
  end

  if current_adapter?(:MysqlAdapter, :Mysql2Adapter)
    def test_schema_dump_should_add_default_value_for_mysql_text_field
      output = standard_dump
      assert_match %r{t.text\s+"body",\s+limit: 65535,\s+null: false$}, output
    end

    def test_schema_dump_includes_length_for_mysql_binary_fields
      output = standard_dump
      assert_match %r{t.binary\s+"var_binary",\s+limit: 255$}, output
      assert_match %r{t.binary\s+"var_binary_large",\s+limit: 4095$}, output
    end

    def test_schema_dump_includes_length_for_mysql_blob_and_text_fields
      output = standard_dump
      assert_match %r{t.binary\s+"tiny_blob",\s+limit: 255$}, output
      assert_match %r{t.binary\s+"normal_blob",\s+limit: 65535$}, output
      assert_match %r{t.binary\s+"medium_blob",\s+limit: 16777215$}, output
      assert_match %r{t.binary\s+"long_blob",\s+limit: 4294967295$}, output
      assert_match %r{t.text\s+"tiny_text",\s+limit: 255$}, output
      assert_match %r{t.text\s+"normal_text",\s+limit: 65535$}, output
      assert_match %r{t.text\s+"medium_text",\s+limit: 16777215$}, output
      assert_match %r{t.text\s+"long_text",\s+limit: 4294967295$}, output
    end

    def test_schema_dumps_index_type
      output = standard_dump
      assert_match %r{add_index "key_tests", \["awesome"\], name: "index_key_tests_on_awesome", type: :fulltext}, output
      assert_match %r{add_index "key_tests", \["pizza"\], name: "index_key_tests_on_pizza", using: :btree}, output
    end
  end

  if mysql_56?
    def test_schema_dump_includes_datetime_precision
      output = standard_dump
      assert_match %r{t.datetime\s+"written_on",\s+precision: 6$}, output
    end
  end

  def test_schema_dump_includes_decimal_options
    output = dump_all_table_schema([/^[^n]/])
    assert_match %r{precision: 3,[[:space:]]+scale: 2,[[:space:]]+default: 2.78}, output
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_schema_dump_includes_bigint_default
      output = standard_dump
      assert_match %r{t.integer\s+"bigint_default",\s+limit: 8,\s+default: 0}, output
    end

    if ActiveRecord::Base.connection.supports_extensions?
      def test_schema_dump_includes_extensions
        connection = ActiveRecord::Base.connection

        connection.stubs(:extensions).returns(['hstore'])
        output = perform_schema_dump
        assert_match "# These are extensions that must be enabled", output
        assert_match %r{enable_extension "hstore"}, output

        connection.stubs(:extensions).returns([])
        output = perform_schema_dump
        assert_no_match "# These are extensions that must be enabled", output
        assert_no_match %r{enable_extension}, output
      end
    end
  end

  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump
    # Oracle supports precision up to 38 and it identifies decimals with scale 0 as integers
    if current_adapter?(:OracleAdapter)
      assert_match %r{t.integer\s+"atoms_in_universe",\s+precision: 38}, output
    elsif current_adapter?(:FbAdapter)
      assert_match %r{t.integer\s+"atoms_in_universe",\s+precision: 18}, output
    else
      assert_match %r{t.decimal\s+"atoms_in_universe",\s+precision: 55}, output
    end
  end

  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
    output = standard_dump
    match = output.match(%r{create_table "goofy_string_id"(.*)do.*\n(.*)\n})
    assert_not_nil(match, "goofy_string_id table not found")
    assert_match %r(id: false), match[1], "no table id not preserved"
    assert_match %r{t.string\s+"id",.*?null: false$}, match[2], "non-primary key id column not preserved"
  end

  def test_schema_dump_keeps_id_false_when_id_is_false_and_unique_not_null_column_added
    output = standard_dump
    assert_match %r{create_table "subscribers", id: false}, output
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

  class CreateDogMigration < ActiveRecord::Migration
    def up
      create_table("dog_owners") do |t|
      end

      create_table("dogs") do |t|
        t.column :name, :string
        t.column :owner_id, :integer
      end
      add_index "dogs", [:name]
      add_foreign_key :dogs, :dog_owners, column: "owner_id" if supports_foreign_keys?
    end
    def down
      drop_table("dogs")
      drop_table("dog_owners")
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = 'foo_'
    ActiveRecord::Base.table_name_suffix = '_bar'

    migration = CreateDogMigration.new
    migration.migrate(:up)

    output = perform_schema_dump
    assert_no_match %r{create_table "foo_.+_bar"}, output
    assert_no_match %r{add_index "foo_.+_bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output

    if ActiveRecord::Base.connection.supports_foreign_keys?
      assert_no_match %r{add_foreign_key "foo_.+_bar"}, output
      assert_no_match %r{add_foreign_key "[^"]+", "foo_.+_bar"}, output
    end
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ''
    $stdout = original
  end
end

class SchemaDumperDefaultsTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table :defaults, force: true do |t|
      t.string   :string_with_default,   default: "Hello!"
      t.date     :date_with_default,     default: '2014-06-05'
      t.datetime :datetime_with_default, default: "2014-06-05 07:17:04"
      t.time     :time_with_default,     default: "07:17:04"
    end
  end

  teardown do
    return unless @connection
    @connection.execute 'DROP TABLE defaults' if @connection.table_exists? 'defaults'
  end

  def test_schema_dump_defaults_with_universally_supported_types
    output = dump_table_schema('defaults')

    assert_match %r{t\.string\s+"string_with_default",.*?default: "Hello!"}, output
    assert_match %r{t\.date\s+"date_with_default",\s+default: '2014-06-05'}, output
    assert_match %r{t\.datetime\s+"datetime_with_default",\s+default: '2014-06-05 07:17:04'}, output
    assert_match %r{t\.time\s+"time_with_default",\s+default: '2000-01-01 07:17:04'}, output
  end
end
