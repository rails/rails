require 'abstract_unit'

class SchemaTest < Test::Unit::TestCase
  self.use_transactional_fixtures = false

  SCHEMA_NAME = 'test_schema'
  TABLE_NAME = 'things'
  COLUMNS = [
    'id integer',
    'name character varying(50)',
    'moment timestamp without time zone default now()'
  ]

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE SCHEMA #{SCHEMA_NAME} CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
  end

  def teardown
    @connection.execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  def test_with_schema_prefixed_table_name
    assert_nothing_raised do
      assert_equal COLUMNS, columns("#{SCHEMA_NAME}.#{TABLE_NAME}")
    end
  end

  def test_with_schema_search_path
    assert_nothing_raised do
      with_schema_search_path(SCHEMA_NAME) do
        assert_equal COLUMNS, columns(TABLE_NAME)
      end
    end
  end

  def test_raise_on_unquoted_schema_name
    assert_raise(ActiveRecord::StatementInvalid) do
      with_schema_search_path '$user,public'
    end
  end

  def test_without_schema_search_path
    assert_raise(ActiveRecord::StatementInvalid) { columns(TABLE_NAME) }
  end

  def test_ignore_nil_schema_search_path
    assert_nothing_raised { with_schema_search_path nil }
  end

  private
    def columns(table_name)
      @connection.send(:column_definitions, table_name).map do |name, type, default|
        "#{name} #{type}" + (default ? " default #{default}" : '')
      end
    end

    def with_schema_search_path(schema_search_path)
      @connection.schema_search_path = schema_search_path
      yield if block_given?
    ensure
      @connection.schema_search_path = "'$user', public"
    end
end
