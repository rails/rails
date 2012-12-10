require "cases/helper"


class SchemaDumperTest < ActiveRecord::TestCase
  def setup
    super
    ActiveRecord::SchemaMigration.create_table
    @stream = StringIO.new
  end

  def standard_dump
    @stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = []
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, @stream)
    @stream.string
  end

  def test_dump_schema_information_outputs_lexically_ordered_versions
    versions = %w{ 20100101010101 20100201010101 20100301010101 }
    versions.reverse.each do |v|
      ActiveRecord::SchemaMigration.create!(:version => v)
    end

    schema_info = ActiveRecord::Base.connection.dump_schema_information
    assert_match(/20100201010101.*20100301010101/m, schema_info)
  end

  def test_magic_comment
    assert_match "# encoding: #{@stream.external_encoding.name}", standard_dump
  end

  def test_schema_dump
    output = standard_dump
    assert_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
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
        if match = column.match(/t\.(?:integer|decimal|float|datetime|timestamp|time|date|text|binary|string|boolean)\s+"/)
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
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [/^[^r]/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_match %r{null: false}, output
  end

  def test_schema_dump_includes_limit_constraint_for_integer_columns
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [/^(?!integer_limits)/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string

    if current_adapter?(:PostgreSQLAdapter)
      assert_match %r{c_int_1.*limit: 2}, output
      assert_match %r{c_int_2.*limit: 2}, output

      # int 3 is 4 bytes in postgresql
      assert_match %r{c_int_3.*}, output
      assert_no_match %r{c_int_3.*limit:}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*limit:}, output
    elsif current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*:limit}, output
    elsif current_adapter?(:SQLite3Adapter)
      assert_match %r{c_int_1.*limit: 1}, output
      assert_match %r{c_int_2.*limit: 2}, output
      assert_match %r{c_int_3.*limit: 3}, output
      assert_match %r{c_int_4.*limit: 4}, output
    end
    assert_match %r{c_int_without_limit.*}, output
    assert_no_match %r{c_int_without_limit.*limit:}, output

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
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = ['accounts']
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_with_regexp_ignored_table
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [/^account/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_no_match %r{create_table "accounts"}, output
    assert_match %r{create_table "authors"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  end

  def test_schema_dump_illegal_ignored_table_value
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = [5]
    assert_raise(StandardError) do
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    end
  end

  def test_schema_dumps_index_columns_in_right_order
    index_definition = standard_dump.split(/\n/).grep(/add_index.*companies/).first.strip
    assert_equal 'add_index "companies", ["firm_id", "type", "rating"], name: "company_index"', index_definition
  end

  def test_schema_dumps_partial_indices
    index_definition = standard_dump.split(/\n/).grep(/add_index.*company_partial_index/).first.strip
    if current_adapter?(:PostgreSQLAdapter)
      assert_equal 'add_index "companies", ["firm_id", "type"], name: "company_partial_index", where: "(rating > 10)"', index_definition
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

  if current_adapter?(:MysqlAdapter) or current_adapter?(:Mysql2Adapter)
    def test_schema_dump_should_not_add_default_value_for_mysql_text_field
      output = standard_dump
      assert_match %r{t.text\s+"body",\s+null: false$}, output
    end

    def test_schema_dump_includes_length_for_mysql_binary_fields
      output = standard_dump
      assert_match %r{t.binary\s+"var_binary",\s+limit: 255$}, output
      assert_match %r{t.binary\s+"var_binary_large",\s+limit: 4095$}, output
    end

    def test_schema_dump_includes_length_for_mysql_blob_and_text_fields
      output = standard_dump
      assert_match %r{t.binary\s+"tiny_blob",\s+limit: 255$}, output
      assert_match %r{t.binary\s+"normal_blob"$}, output
      assert_match %r{t.binary\s+"medium_blob",\s+limit: 16777215$}, output
      assert_match %r{t.binary\s+"long_blob",\s+limit: 2147483647$}, output
      assert_match %r{t.text\s+"tiny_text",\s+limit: 255$}, output
      assert_match %r{t.text\s+"normal_text"$}, output
      assert_match %r{t.text\s+"medium_text",\s+limit: 16777215$}, output
      assert_match %r{t.text\s+"long_text",\s+limit: 2147483647$}, output
    end
  end

  def test_schema_dump_includes_decimal_options
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = [/^[^n]/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_match %r{precision: 3,[[:space:]]+scale: 2,[[:space:]]+default: 2.78}, output
  end

  if current_adapter?(:PostgreSQLAdapter)
    def test_schema_dump_includes_xml_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_xml_data_type"} =~ output
        assert_match %r{t.xml "data"}, output
      end
    end

    def test_schema_dump_includes_json_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_json_data_type"} =~ output
        assert_match %r|t.json "json_data", default: {}|, output
      end
    end

    def test_schema_dump_includes_inet_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_network_address"} =~ output
        assert_match %r{t.inet "inet_address"}, output
      end
    end

    def test_schema_dump_includes_cidr_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_network_address"} =~ output
        assert_match %r{t.cidr "cidr_address"}, output
      end
    end

    def test_schema_dump_includes_macaddr_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_network_address"} =~ output
        assert_match %r{t.macaddr "macaddr_address"}, output
      end
    end

    def test_schema_dump_includes_uuid_shorthand_definition
      output = standard_dump
      if %r{create_table "poistgresql_uuids"} =~ output
        assert_match %r{t.uuid "guid"}, output
      end
    end

    def test_schema_dump_includes_hstores_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_hstores"} =~ output
        assert_match %r[t.hstore "hash_store", default: {}], output
      end
    end

    def test_schema_dump_includes_arrays_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_arrays"} =~ output
        assert_match %r[t.text\s+"nicknames",\s+array: true], output
        assert_match %r[t.integer\s+"commission_by_quarter",\s+array: true], output
      end
    end

    def test_schema_dump_includes_tsvector_shorthand_definition
      output = standard_dump
      if %r{create_table "postgresql_tsvectors"} =~ output
        assert_match %r{t.tsvector "text_vector"}, output
      end
    end
  end

  def test_schema_dump_keeps_large_precision_integer_columns_as_decimal
    output = standard_dump
    # Oracle supports precision up to 38 and it identifies decimals with scale 0 as integers
    if current_adapter?(:OracleAdapter)
      assert_match %r{t.integer\s+"atoms_in_universe",\s+precision: 38,\s+scale: 0}, output
    else
      assert_match %r{t.decimal\s+"atoms_in_universe",\s+precision: 55,\s+scale: 0}, output
    end
  end

  def test_schema_dump_keeps_id_column_when_id_is_false_and_id_column_added
    output = standard_dump
    match = output.match(%r{create_table "goofy_string_id"(.*)do.*\n(.*)\n})
    assert_not_nil(match, "goofy_string_id table not found")
    assert_match %r(id: false), match[1], "no table id not preserved"
    assert_match %r{t.string[[:space:]]+"id",[[:space:]]+null: false$}, match[2], "non-primary key id column not preserved"
  end

  def test_schema_dump_keeps_id_false_when_id_is_false_and_unique_not_null_column_added
    output = standard_dump
    assert_match %r{create_table "subscribers", id: false}, output
  end

  class CreateDogMigration < ActiveRecord::Migration
    def up
      create_table("dogs") do |t|
        t.column :name, :string
      end
      add_index "dogs", [:name]
    end
    def down
      drop_table("dogs")
    end
  end

  def test_schema_dump_with_table_name_prefix_and_suffix
    original, $stdout = $stdout, StringIO.new
    ActiveRecord::Base.table_name_prefix = 'foo_'
    ActiveRecord::Base.table_name_suffix = '_bar'

    migration = CreateDogMigration.new
    migration.migrate(:up)

    output = standard_dump
    assert_no_match %r{create_table "foo_.+_bar"}, output
    assert_no_match %r{create_index "foo_.+_bar"}, output
    assert_no_match %r{create_table "schema_migrations"}, output
  ensure
    migration.migrate(:down)

    ActiveRecord::Base.table_name_suffix = ActiveRecord::Base.table_name_prefix = ''
    $stdout = original
  end

end
