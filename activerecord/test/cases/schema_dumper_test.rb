# frozen_string_literal: true

require "cases/helper"
require "support/schema_dumping_helper"

class SchemaDumperTest < ActiveRecord::TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  setup do
    @schema_migration = ActiveRecord::Base.connection_pool.schema_migration
    @schema_migration.create_table

    ARUnit2Model.connection_pool.schema_migration.create_table
  end

  def standard_dump
    @@standard_dump ||= dump_all_table_schema
  end

  def test_dump_schema_versions_with_empty_versions
    @schema_migration.delete_all_versions
    schema_info = ActiveRecord::Base.lease_connection.dump_schema_versions
    assert_no_match(/INSERT INTO/, schema_info)
  end

  def test_dump_schema_versions_outputs_lexically_reverse_ordered_versions_regardless_of_database_order
    versions = %w{ 20100101010101 20100201010101 20100301010101 }
    versions.shuffle.each do |v|
      @schema_migration.create_version(v)
    end

    schema_info = ActiveRecord::Base.lease_connection.dump_schema_versions
    expected = <<~STR
    INSERT INTO #{quote_table_name("schema_migrations")} (version) VALUES
    ('20100301010101'),
    ('20100201010101'),
    ('20100101010101');
    STR
    assert_equal expected.strip, schema_info
  ensure
    @schema_migration.delete_all_versions
  end

  def test_schema_dump_include_migration_version
    output = standard_dump
    assert_match %r{ActiveRecord::Schema\[#{ActiveRecord::Migration.current_version}\]\.define}, output
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

      # int 3 is 4 bytes in PostgreSQL
      assert_match %r{"c_int_3"(?!.*limit)}, output
      assert_match %r{"c_int_4"(?!.*limit)}, output
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
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

    if current_adapter?(:SQLite3Adapter)
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
    output = dump_table_schema("authors")
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    output = dump_all_table_schema([/^courses/], pool: ARUnit2Model.connection_pool)
    assert_no_match %r{create_table "courses"}, output
    assert_match %r{create_table "colleges"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output
  end

  def test_table_columns_sorted
    column_names = column_definition_lines(dump_table_schema("companies")).flatten.filter_map do |line|
      $1 if line !~ /t\.index/ && line.match(/t\..*"(\w+)"/)
    end

    assert_equal %w[account_id client_of description firm_id firm_name name rating status type], column_names
  end

  def test_schema_dumps_index_columns_in_right_order
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_index/).first.strip
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      if ActiveRecord::Base.lease_connection.supports_index_sort_order?
        assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", length: { type: 10 }, order: { rating: :desc }', index_definition
      else
        assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", length: { type: 10 }', index_definition
      end
    elsif ActiveRecord::Base.lease_connection.supports_index_sort_order?
      assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index", order: { rating: :desc }', index_definition
    else
      assert_equal 't.index ["firm_id", "type", "rating"], name: "company_index"', index_definition
    end
  end

  def test_schema_dumps_partial_indices
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_partial_index/).first.strip
    if ActiveRecord::Base.lease_connection.supports_partial_index?
      assert_equal 't.index ["firm_id", "type"], name: "company_partial_index", where: "(rating > 10)"', index_definition
    else
      assert_equal 't.index ["firm_id", "type"], name: "company_partial_index"', index_definition
    end
  end

  def test_schema_dumps_nulls_not_distinct
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_nulls_not_distinct/).first.strip
    if supports_nulls_not_distinct?
      assert_equal 't.index ["firm_id"], name: "company_nulls_not_distinct", nulls_not_distinct: true', index_definition
    else
      assert_equal 't.index ["firm_id"], name: "company_nulls_not_distinct"', index_definition
    end
  end

  def test_schema_dumps_index_sort_order
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*_name_and_rating/).first.strip
    if ActiveRecord::Base.lease_connection.supports_index_sort_order?
      assert_equal 't.index ["name", "rating"], name: "index_companies_on_name_and_rating", order: :desc', index_definition
    else
      assert_equal 't.index ["name", "rating"], name: "index_companies_on_name_and_rating"', index_definition
    end
  end

  def test_schema_dumps_index_length
    index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*_name_and_description/).first.strip
    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      assert_equal 't.index ["name", "description"], name: "index_companies_on_name_and_description", length: 10', index_definition
    else
      assert_equal 't.index ["name", "description"], name: "index_companies_on_name_and_description"', index_definition
    end
  end

  if ActiveRecord::Base.lease_connection.supports_check_constraints?
    def test_schema_dumps_check_constraints
      constraint_definition = dump_table_schema("products").split(/\n/).grep(/t.check_constraint.*products_price_check/).first.strip
      if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        assert_equal 't.check_constraint "`price` > `discounted_price`", name: "products_price_check"', constraint_definition
      else
        assert_equal 't.check_constraint "price > discounted_price", name: "products_price_check"', constraint_definition
      end
    end
  end

  if ActiveRecord::Base.lease_connection.supports_exclusion_constraints?
    def test_schema_dumps_exclusion_constraints
      output = dump_table_schema("test_exclusion_constraints")
      constraint_definitions = output.split(/\n/).grep(/test_exclusion_constraints_.*_overlap/)

      assert_equal 3, constraint_definitions.size
      assert_match 't.exclusion_constraint "daterange(start_date, end_date) WITH &&", where: "(start_date IS NOT NULL) AND (end_date IS NOT NULL)", using: :gist, name: "test_exclusion_constraints_date_overlap"', output
      assert_match 't.exclusion_constraint "daterange(valid_from, valid_to) WITH &&", where: "(valid_from IS NOT NULL) AND (valid_to IS NOT NULL)", using: :gist, deferrable: :immediate, name: "test_exclusion_constraints_valid_overlap"', output
      assert_match 't.exclusion_constraint "daterange(transaction_from, transaction_to) WITH &&", where: "(transaction_from IS NOT NULL) AND (transaction_to IS NOT NULL)", using: :gist, deferrable: :deferred, name: "test_exclusion_constraints_transaction_overlap"', output
    end
  end

  if ActiveRecord::Base.lease_connection.supports_unique_constraints?
    def test_schema_dumps_unique_constraints
      output = dump_table_schema("test_unique_constraints")
      constraint_definitions = output.split(/\n/).grep(/t\.unique_constraint/)

      assert_equal 4, constraint_definitions.size
      assert_match 't.unique_constraint ["position_1"], name: "test_unique_constraints_position_deferrable_false"', output
      assert_match 't.unique_constraint ["position_2"], deferrable: :immediate, name: "test_unique_constraints_position_deferrable_immediate"', output
      assert_match 't.unique_constraint ["position_3"], deferrable: :deferred, name: "test_unique_constraints_position_deferrable_deferred"', output
      assert_match 't.unique_constraint ["position_4"], nulls_not_distinct: true, name: "test_unique_constraints_position_nulls_not_distinct"', output
    end

    def test_schema_does_not_dump_unique_constraints_as_indexes
      output = dump_table_schema("test_unique_constraints")
      unique_index_definitions = output.split(/\n/).grep(/t\.index.*unique: true/)

      assert_equal 0, unique_index_definitions.size
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

  def test_schema_dump_aliased_types
    output = standard_dump
    assert_match %r{t\.binary\s+"blob_data"$}, output
    assert_match %r{t\.decimal\s+"numeric_number"}, output
  end

  if ActiveRecord::Base.lease_connection.supports_expression_index?
    def test_schema_dump_expression_indices
      index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*company_expression_index/).first.strip
      index_definition.sub!(/, name: "company_expression_index"\z/, "")

      if current_adapter?(:PostgreSQLAdapter)
        assert_match %r{CASE.+lower\(\(name\)::text\).+END\) DESC"\z}i, index_definition
      elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
        assert_match %r{CASE.+lower\(`name`\).+END\) DESC"\z}i, index_definition
      elsif current_adapter?(:SQLite3Adapter)
        assert_match %r{CASE.+lower\(name\).+END\) DESC"\z}i, index_definition
      else
        assert false
      end
    end

    if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      def test_schema_dump_expression_indices_escaping
        index_definition = dump_table_schema("companies").split(/\n/).grep(/t\.index.*full_name_index/).first.strip
        index_definition.sub!(/, name: "full_name_index"\z/, "")

        assert_match %r{concat_ws\(`firm_name`,`name`,_utf8mb4' '\)\)"\z}i, index_definition
      end
    end
  end

  if current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
    def test_schema_dump_includes_length_for_mysql_binary_fields
      output = dump_table_schema "binary_fields"
      assert_match %r{t\.binary\s+"var_binary",\s+limit: 255$}, output
      assert_match %r{t\.binary\s+"var_binary_large",\s+limit: 4095$}, output
    end

    def test_schema_dump_includes_length_for_mysql_blob_and_text_fields
      output = dump_table_schema "binary_fields"
      assert_match %r{t\.binary\s+"tiny_blob",\s+size: :tiny$}, output
      assert_match %r{t\.binary\s+"normal_blob"$}, output
      assert_match %r{t\.binary\s+"medium_blob",\s+size: :medium$}, output
      assert_match %r{t\.binary\s+"long_blob",\s+size: :long$}, output
      assert_match %r{t\.text\s+"tiny_text",\s+size: :tiny$}, output
      assert_match %r{t\.text\s+"normal_text"$}, output
      assert_match %r{t\.text\s+"medium_text",\s+size: :medium$}, output
      assert_match %r{t\.text\s+"long_text",\s+size: :long$}, output
      assert_match %r{t\.binary\s+"tiny_blob_2",\s+size: :tiny$}, output
      assert_match %r{t\.binary\s+"medium_blob_2",\s+size: :medium$}, output
      assert_match %r{t\.binary\s+"long_blob_2",\s+size: :long$}, output
      assert_match %r{t\.text\s+"tiny_text_2",\s+size: :tiny$}, output
      assert_match %r{t\.text\s+"medium_text_2",\s+size: :medium$}, output
      assert_match %r{t\.text\s+"long_text_2",\s+size: :long$}, output
    end

    def test_schema_does_not_include_limit_for_emulated_mysql_boolean_fields
      output = dump_table_schema "booleans"
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
      assert_match %r{t\.bigint\s+"big_int_data_points",\s+array: true}, output
    end

    def test_schema_dump_allows_array_of_decimal_defaults
      output = dump_table_schema "bigint_array"
      assert_match %r{t\.decimal\s+"decimal_array_default",\s+default: \["1.23", "3.45"\],\s+array: true}, output
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
      connection = ActiveRecord::Base.lease_connection

      connection.stub(:extensions, ["hstore"]) do
        output = dump_all_table_schema(/./)
        assert_match "# These are extensions that must be enabled", output
        assert_match %r{enable_extension "hstore"}, output
      end

      connection.stub(:extensions, []) do
        output = dump_all_table_schema(/./)
        assert_no_match "# These are extensions that must be enabled", output
        assert_no_match %r{enable_extension}, output
      end
    end

    def test_schema_dump_includes_extensions_in_alphabetic_order
      connection = ActiveRecord::Base.lease_connection

      connection.stub(:extensions, ["hstore", "uuid-ossp", "xml2"]) do
        output = dump_all_table_schema(/./)
        enabled_extensions = output.scan(%r{enable_extension "(.+)"}).flatten
        assert_equal ["hstore", "uuid-ossp", "xml2"], enabled_extensions
      end

      connection.stub(:extensions, ["uuid-ossp", "xml2", "hstore"]) do
        output = dump_all_table_schema(/./)
        enabled_extensions = output.scan(%r{enable_extension "(.+)"}).flatten
        assert_equal ["hstore", "uuid-ossp", "xml2"], enabled_extensions
      end
    end

    def test_schema_dump_include_limit_for_float4_field
      output = dump_table_schema "numeric_data"
      assert_match %r{t\.float\s+"temperature_with_limit",\s+limit: 24$}, output
    end

    def test_schema_dump_keeps_enum_intact_if_it_contains_comma
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_enum "enum_with_comma", ["value1", "value,2", "value3"]
        end

        def down
          drop_enum "enum_with_comma"
        end
      end

      migration.migrate(:up)
      output = dump_all_table_schema

      assert_includes output, 'create_enum "enum_with_comma", ["value1", "value,2", "value3"]', output
    ensure
      migration.migrate(:down)
      $stdout = original
    end
  end

  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump

    assert_match %r{t\.decimal\s+"atoms_in_universe",\s+precision: 55}, output
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

  if ActiveRecord::Base.lease_connection.supports_foreign_keys?
    def test_foreign_keys_are_dumped_at_the_bottom_to_circumvent_dependency_issues
      output = standard_dump
      assert_match(/^\s+add_foreign_key "fk_test_has_fk"[^\n]+\n\s+add_foreign_key "lessons_students"/, output)
    end

    def test_do_not_dump_foreign_keys_for_ignored_tables
      output = dump_table_schema "authors"
      assert_equal ["authors"], output.scan(/^\s*add_foreign_key "([^"]+)".+$/).flatten
    end

    unless in_memory_db?
      def test_do_not_dump_foreign_keys_when_bypassed_by_config
        ActiveRecord::Base.establish_connection(
          {
            adapter: "sqlite3",
            database: "test/storage/test.sqlite3",
            foreign_keys: false,
          }
        )

        output = dump_all_table_schema
        assert_no_match(/^\s+add_foreign_key "fk_test_has_fk"[^\n]+\n\s+add_foreign_key "lessons_students"/, output)
      ensure
        ActiveRecord::Base.establish_connection(:arunit)
      end
    end
  end

  class CreateCatMigration < ActiveRecord::Migration::Current
    def up
      create_table("cat_owners") do |t|
      end

      create_table("cats") do |t|
        t.column :name, :string
        t.references :owner
        t.index [:name]
        t.foreign_key :cat_owners, column: "owner_id"
      end
    end
    def down
      drop_table("cats")
      drop_table("cat_owners")
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    ActiveRecord::Base.establish_connection(:arunit2) unless in_memory_db?
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = "foo_"
    ActiveRecord::Base.table_name_suffix = "_bar"

    migration = CreateCatMigration.new
    migration.migrate(:up)

    output = dump_table_schema("foo_cat_owners_bar", "foo_cats_bar")

    assert_match %r{create_table "cat_owners"}, output
    assert_match %r{create_table "cats"}, output
    assert_match %r{t\.index \["name"\], name: "index_foo_cats_bar_on_name"}, output
    assert_no_match %r{create_table "foo_.+_bar"}, output
    assert_no_match %r{add_index "foo_.+_bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output

    if ActiveRecord::Base.lease_connection.supports_foreign_keys?
      assert_match %r{add_foreign_key "cats", "cat_owners", column: "owner_id"}, output
      assert_no_match %r{add_foreign_key "foo_.+_bar"}, output
      assert_no_match %r{add_foreign_key "[^"]+", "foo_.+_bar"}, output
    end
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ""
    $stdout = original
    ActiveRecord::Base.establish_connection(:arunit)
  end

  def test_schema_dump_with_table_name_prefix_and_suffix_regexp_escape
    ActiveRecord::Base.establish_connection(:arunit2) unless in_memory_db?
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = "foo$"
    ActiveRecord::Base.table_name_suffix = "$bar"

    migration = CreateCatMigration.new
    migration.migrate(:up)

    output = dump_table_schema("foo$cat_owners$bar", "foo$cat$bar")

    assert_match %r{create_table "cat_owners"}, output
    assert_match %r{create_table "cats"}, output
    assert_match %r{t\.index \["name"\], name: "index_foo\$cats\$bar_on_name"}, output
    assert_no_match %r{create_table "foo\$.+\$bar"}, output
    assert_no_match %r{add_index "foo\$.+\$bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
    assert_no_match %r{create_table "ar_internal_metadata"}, output

    if ActiveRecord::Base.lease_connection.supports_foreign_keys?
      assert_match %r{add_foreign_key "cats", "cat_owners", column: "owner_id"}, output
      assert_no_match %r{add_foreign_key "foo\$.+\$bar"}, output
      assert_no_match %r{add_foreign_key "[^"]+", "foo\$.+\$bar"}, output
    end
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ""
    $stdout = original
    ActiveRecord::Base.establish_connection(:arunit)
  end

  def test_schema_dump_with_table_name_prefix_and_ignoring_tables
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.establish_connection(:arunit2) unless in_memory_db?

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
    output = ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection_pool, stream).string

    assert_match %r{create_table "omg_cats"}, output
    assert_no_match %r{create_table "cats"}, output
  ensure
    migration.migrate(:down)
    ActiveRecord::Base.table_name_prefix = original_table_name_prefix
    ActiveRecord::SchemaDumper.ignore_tables = original_schema_dumper_ignore_tables

    $stdout = original
    ActiveRecord::Base.establish_connection(:arunit)
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_schema_dump_with_correct_timestamp_types_via_create_table_and_t_column
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_table("timestamps") do |t|
            t.datetime :this_should_remain_datetime
            t.timestamp :this_is_an_alias_of_datetime
            t.column :without_time_zone, :timestamp
            t.column :with_time_zone, :timestamptz
          end
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "this_should_remain_datetime"')
      assert output.include?('t.datetime "this_is_an_alias_of_datetime"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.timestamptz "with_time_zone"')
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_timestamptz_datetime_format
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_postgresql_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration::Current) do
          def up
            create_table("timestamps") do |t|
              t.datetime :this_should_remain_datetime
              t.timestamptz :this_is_an_alias_of_datetime
              t.column :without_time_zone, :timestamp
              t.column :with_time_zone, :timestamptz
            end
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = dump_table_schema("timestamps")
        assert output.include?('t.datetime "this_should_remain_datetime"')
        assert output.include?('t.datetime "this_is_an_alias_of_datetime"')
        assert output.include?('t.timestamp "without_time_zone"')
        assert output.include?('t.datetime "with_time_zone"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_timestamps_schema_dump_before_rails_7
      migration, original, $stdout = nil, $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration[6.1]) do
        def up
          create_table("timestamps") do |t|
            t.datetime :this_should_remain_datetime
            t.timestamp :this_is_an_alias_of_datetime
            t.column :this_is_also_an_alias_of_datetime, :timestamp
          end
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "this_should_remain_datetime"')
      assert output.include?('t.datetime "this_is_an_alias_of_datetime"')
      assert output.include?('t.datetime "this_is_also_an_alias_of_datetime"')
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_timestamps_schema_dump_before_rails_7_with_timestamptz_setting
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_postgresql_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps") do |t|
              t.datetime :this_should_change_to_timestamp
              t.timestamp :this_should_stay_as_timestamp
              t.column :this_should_also_stay_as_timestamp, :timestamp
            end
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = dump_table_schema("timestamps")
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.
        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
        assert output.include?('t.timestamp "this_should_also_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_when_changing_datetime_type_for_an_existing_app
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_table("timestamps") do |t|
            t.datetime :default_format
            t.column :without_time_zone, :timestamp
            t.column :with_time_zone, :timestamptz
          end
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "default_format"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.timestamptz "with_time_zone"')

      datetime_type_was = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz

      output = dump_table_schema("timestamps")
      assert output.include?('t.timestamp "default_format"')
      assert output.include?('t.timestamp "without_time_zone"')
      assert output.include?('t.datetime "with_time_zone"')
    ensure
      ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = datetime_type_was
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_create_table_and_t_timestamptz
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_table("timestamps") do |t|
            t.datetime :default_format
            t.datetime :without_time_zone
            t.timestamp :also_without_time_zone
            t.timestamptz :with_time_zone
          end
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "default_format"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.datetime "also_without_time_zone"')
      assert output.include?('t.timestamptz "with_time_zone"')
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration::Current) do
        def up
          create_table("timestamps")

          add_column :timestamps, :default_format, :datetime
          add_column :timestamps, :without_time_zone, :datetime
          add_column :timestamps, :also_without_time_zone, :timestamp
          add_column :timestamps, :with_time_zone, :timestamptz
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "default_format"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.datetime "also_without_time_zone"')
      assert output.include?('t.timestamptz "with_time_zone"')
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column_before_rails_7
      original, $stdout = $stdout, StringIO.new

      migration = Class.new(ActiveRecord::Migration[6.1]) do
        def up
          create_table("timestamps")

          add_column :timestamps, :default_format, :datetime
          add_column :timestamps, :without_time_zone, :datetime
          add_column :timestamps, :also_without_time_zone, :timestamp
        end
        def down
          drop_table("timestamps")
        end
      end
      migration.migrate(:up)

      output = dump_table_schema("timestamps")
      assert output.include?('t.datetime "default_format"')
      assert output.include?('t.datetime "without_time_zone"')
      assert output.include?('t.datetime "also_without_time_zone"')
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column_before_rails_7_with_timestamptz_setting
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_postgresql_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps")

            add_column :timestamps, :this_should_change_to_timestamp, :datetime
            add_column :timestamps, :this_should_stay_as_timestamp, :timestamp
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = dump_table_schema("timestamps")
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.
        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end

    def test_schema_dump_with_correct_timestamp_types_via_add_column_with_type_as_string
      migration, original, $stdout = nil, $stdout, StringIO.new

      with_postgresql_datetime_type(:timestamptz) do
        migration = Class.new(ActiveRecord::Migration[6.1]) do
          def up
            create_table("timestamps")

            add_column :timestamps, :this_should_change_to_timestamp, "datetime"
            add_column :timestamps, :this_should_stay_as_timestamp, "timestamp"
          end
          def down
            drop_table("timestamps")
          end
        end
        migration.migrate(:up)

        output = dump_table_schema("timestamps")
        # Normally we'd write `t.datetime` here. But because you've changed the `datetime_type`
        # to something else, `t.datetime` now means `:timestamptz`. To ensure that old columns
        # are still created as a `:timestamp` we need to change what is written to the schema dump.
        #
        # Typically in Rails we handle this through Migration versioning (`ActiveRecord::Migration::Compatibility`)
        # but that doesn't work here because the schema dumper is not aware of which migration
        # a column was added in.
        assert output.include?('t.timestamp "this_should_change_to_timestamp"')
        assert output.include?('t.timestamp "this_should_stay_as_timestamp"')
      end
    ensure
      migration.migrate(:down)
      $stdout = original
    end
  end
end

class SchemaDumperDefaultsTest < ActiveRecord::TestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table :dump_defaults, force: true do |t|
      t.string   :string_with_default,   default: "Hello!"
      t.date     :date_with_default,     default: "2014-06-05"
      t.datetime :datetime_with_default, default: "2014-06-05 07:17:04"
      t.time     :time_with_default,     default: "07:17:04"
      t.decimal  :decimal_with_default,  default: "1234567890.0123456789", precision: 20, scale: 10

      if supports_text_column_with_default?
        t.text :text_with_default, default: "John' Doe"

        if current_adapter?(:PostgreSQLAdapter)
          t.text :uuid, default: -> { "gen_random_uuid()" }
        else
          t.text :uuid, default: -> { "uuid()" }
        end
      end
    end

    if current_adapter?(:PostgreSQLAdapter)
      @connection.create_table :infinity_defaults, force: true do |t|
        t.float    :float_with_inf_default,    default: Float::INFINITY
        t.float    :float_with_nan_default,    default: Float::NAN
        t.datetime :beginning_of_time,         default: "-infinity"
        t.datetime :end_of_time,               default: "infinity"
        t.date :date_with_neg_inf_default,     default: -::Float::INFINITY
        t.date :date_with_pos_inf_default,     default: ::Float::INFINITY
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

  def test_schema_dump_with_text_column
    output = dump_table_schema("dump_defaults")

    assert_match %r{t\.text\s+"text_with_default",.*?default: "John' Doe"}, output

    if current_adapter?(:PostgreSQLAdapter)
      assert_match %r{t\.text\s+"uuid",.*?default: -> \{ "gen_random_uuid\(\)" \}}, output
    else
      assert_match %r{t\.text\s+"uuid",.*?default: -> \{ "uuid\(\)" \}}, output
    end
  end if supports_text_column_with_default?

  def test_schema_dump_with_column_infinity_default
    output = dump_table_schema("infinity_defaults")
    assert_match %r{t\.float\s+"float_with_inf_default",\s+default: ::Float::INFINITY}, output
    assert_match %r{t\.float\s+"float_with_nan_default",\s+default: ::Float::NAN}, output
    assert_match %r{t\.datetime\s+"beginning_of_time",\s+default: -::Float::INFINITY}, output
    assert_match %r{t\.datetime\s+"end_of_time",\s+default: ::Float::INFINITY}, output
    assert_match %r{t\.date\s+"date_with_neg_inf_default",\s+default: -::Float::INFINITY}, output
    assert_match %r{t\.date\s+"date_with_pos_inf_default",\s+default: ::Float::INFINITY}, output
  end if current_adapter?(:PostgreSQLAdapter)
end
