require "cases/helper"
require 'active_record/schema_dumper'
require 'stringio'


class SchemaDumperTest < ActiveRecord::TestCase
  def standard_dump
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = []
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    stream.string
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
      assert_line_up(column_set, /:default => /)
      assert_line_up(column_set, /:limit => /)
      assert_line_up(column_set, /:null => /)
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
    assert_match %r{:null => false}, output
  end

  def test_schema_dump_includes_limit_constraint_for_integer_columns
    stream = StringIO.new

    ActiveRecord::SchemaDumper.ignore_tables = [/^(?!integer_limits)/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string

    if current_adapter?(:PostgreSQLAdapter)
      assert_match %r{c_int_1.*:limit => 2}, output
      assert_match %r{c_int_2.*:limit => 2}, output

      # int 3 is 4 bytes in postgresql
      assert_match %r{c_int_3.*}, output
      assert_no_match %r{c_int_3.*:limit}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*:limit}, output
    elsif current_adapter?(:MysqlAdapter)
      assert_match %r{c_int_1.*:limit => 1}, output
      assert_match %r{c_int_2.*:limit => 2}, output
      assert_match %r{c_int_3.*:limit => 3}, output

      assert_match %r{c_int_4.*}, output
      assert_no_match %r{c_int_4.*:limit}, output
    elsif current_adapter?(:SQLiteAdapter)
      assert_match %r{c_int_1.*:limit => 1}, output
      assert_match %r{c_int_2.*:limit => 2}, output
      assert_match %r{c_int_3.*:limit => 3}, output
      assert_match %r{c_int_4.*:limit => 4}, output
    end
    assert_match %r{c_int_without_limit.*}, output
    assert_no_match %r{c_int_without_limit.*:limit}, output

    if current_adapter?(:SQLiteAdapter)
      assert_match %r{c_int_5.*:limit => 5}, output
      assert_match %r{c_int_6.*:limit => 6}, output
      assert_match %r{c_int_7.*:limit => 7}, output
      assert_match %r{c_int_8.*:limit => 8}, output
    else
      assert_match %r{c_int_5.*:limit => 8}, output
      assert_match %r{c_int_6.*:limit => 8}, output
      assert_match %r{c_int_7.*:limit => 8}, output
      assert_match %r{c_int_8.*:limit => 8}, output
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

  if current_adapter?(:MysqlAdapter)
    def test_schema_dump_should_not_add_default_value_for_mysql_text_field
      output = standard_dump
      assert_match %r{t.text\s+"body",\s+:null => false$}, output
    end

    def test_mysql_schema_dump_should_honor_nonstandard_primary_keys
      output = standard_dump
      match = output.match(%r{create_table "movies"(.*)do})
      assert_not_nil(match, "nonstandardpk table not found")
      assert_match %r(:primary_key => "movieid"), match[1], "non-standard primary key not preserved"
    end

    def test_schema_dump_includes_length_for_mysql_blob_and_text_fields
      output = standard_dump
      assert_match %r{t.binary\s+"tiny_blob",\s+:limit => 255$}, output
      assert_match %r{t.binary\s+"normal_blob"$}, output
      assert_match %r{t.binary\s+"medium_blob",\s+:limit => 16777215$}, output
      assert_match %r{t.binary\s+"long_blob",\s+:limit => 2147483647$}, output
      assert_match %r{t.text\s+"tiny_text",\s+:limit => 255$}, output
      assert_match %r{t.text\s+"normal_text"$}, output
      assert_match %r{t.text\s+"medium_text",\s+:limit => 16777215$}, output
      assert_match %r{t.text\s+"long_text",\s+:limit => 2147483647$}, output
    end
  end

  def test_schema_dump_includes_decimal_options
    stream = StringIO.new
    ActiveRecord::SchemaDumper.ignore_tables = [/^[^n]/]
    ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
    output = stream.string
    assert_match %r{:precision => 3,[[:space:]]+:scale => 2,[[:space:]]+:default => 2.78}, output
  end
end
