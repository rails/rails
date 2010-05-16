require "cases/helper"

class SchemaTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  SCHEMA_NAME = 'test_schema'
  SCHEMA2_NAME = 'test_schema2'
  TABLE_NAME = 'things'
  CAPITALIZED_TABLE_NAME = 'Things'
  INDEX_A_NAME = 'a_index_things_on_name'
  INDEX_B_NAME = 'b_index_things_on_different_columns_in_each_schema'
  INDEX_A_COLUMN = 'name'
  INDEX_B_COLUMN_S1 = 'email'
  INDEX_B_COLUMN_S2 = 'moment'
  COLUMNS = [
    'id integer',
    'name character varying(50)',
    'email character varying(50)',
    'moment timestamp without time zone default now()'
  ]

  class Thing1 < ActiveRecord::Base
    set_table_name "test_schema.things"
  end

  class Thing2 < ActiveRecord::Base
    set_table_name "test_schema2.things"
  end

  class Thing3 < ActiveRecord::Base
    set_table_name 'test_schema."things.table"'
  end

  class Thing4 < ActiveRecord::Base
    set_table_name 'test_schema."Things"'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.execute "CREATE SCHEMA #{SCHEMA_NAME} CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{TABLE_NAME}.table\" (#{COLUMNS.join(',')})"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{CAPITALIZED_TABLE_NAME}\" (#{COLUMNS.join(',')})"
    @connection.execute "CREATE SCHEMA #{SCHEMA2_NAME} CREATE TABLE #{TABLE_NAME} (#{COLUMNS.join(',')})"
    @connection.execute "CREATE INDEX #{INDEX_A_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_A_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_A_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_A_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_B_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_B_COLUMN_S1});"
    @connection.execute "CREATE INDEX #{INDEX_B_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_B_COLUMN_S2});"
  end

  def teardown
    @connection.execute "DROP SCHEMA #{SCHEMA2_NAME} CASCADE"
    @connection.execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  def test_with_schema_prefixed_table_name
    assert_nothing_raised do
      assert_equal COLUMNS, columns("#{SCHEMA_NAME}.#{TABLE_NAME}")
    end
  end

  def test_with_schema_prefixed_capitalized_table_name
    assert_nothing_raised do
      assert_equal COLUMNS, columns("#{SCHEMA_NAME}.#{CAPITALIZED_TABLE_NAME}")
    end
  end

  def test_with_schema_search_path
    assert_nothing_raised do
      with_schema_search_path(SCHEMA_NAME) do
        assert_equal COLUMNS, columns(TABLE_NAME)
      end
    end
  end


  def test_proper_encoding_of_table_name
    assert_equal '"table_name"', @connection.quote_table_name('table_name')
    assert_equal '"table.name"', @connection.quote_table_name('"table.name"')
    assert_equal '"schema_name"."table_name"', @connection.quote_table_name('schema_name.table_name')
    assert_equal '"schema_name"."table.name"', @connection.quote_table_name('schema_name."table.name"')
    assert_equal '"schema.name"."table_name"', @connection.quote_table_name('"schema.name".table_name')
    assert_equal '"schema.name"."table.name"', @connection.quote_table_name('"schema.name"."table.name"')
  end

  def test_classes_with_qualified_schema_name
    assert_equal 0, Thing1.count
    assert_equal 0, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing1.create(:id => 1, :name => "thing1", :email => "thing1@localhost", :moment => Time.now)
    assert_equal 1, Thing1.count
    assert_equal 0, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing2.create(:id => 1, :name => "thing1", :email => "thing1@localhost", :moment => Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing3.create(:id => 1, :name => "thing1", :email => "thing1@localhost", :moment => Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 1, Thing3.count
    assert_equal 0, Thing4.count

    Thing4.create(:id => 1, :name => "thing1", :email => "thing1@localhost", :moment => Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 1, Thing3.count
    assert_equal 1, Thing4.count
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

  def test_dump_indexes_for_schema_one
    do_dump_index_tests_for_schema(SCHEMA_NAME, INDEX_A_COLUMN, INDEX_B_COLUMN_S1)
  end

  def test_dump_indexes_for_schema_two
    do_dump_index_tests_for_schema(SCHEMA2_NAME, INDEX_A_COLUMN, INDEX_B_COLUMN_S2)
  end

  def test_with_uppercase_index_name
    ActiveRecord::Base.connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_nothing_raised { ActiveRecord::Base.connection.remove_index! "things", "#{SCHEMA_NAME}.things_Index"}

    ActiveRecord::Base.connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    ActiveRecord::Base.connection.schema_search_path = SCHEMA_NAME
    assert_nothing_raised { ActiveRecord::Base.connection.remove_index! "things", "things_Index"}
    ActiveRecord::Base.connection.schema_search_path = "public"
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

    def do_dump_index_tests_for_schema(this_schema_name, first_index_column_name, second_index_column_name)
      with_schema_search_path(this_schema_name) do
        indexes = @connection.indexes(TABLE_NAME).sort_by {|i| i.name}
        assert_equal 2,indexes.size

        do_dump_index_assertions_for_one_index(indexes[0], INDEX_A_NAME, first_index_column_name)
        do_dump_index_assertions_for_one_index(indexes[1], INDEX_B_NAME, second_index_column_name)
      end
    end

    def do_dump_index_assertions_for_one_index(this_index, this_index_name, this_index_column)
      assert_equal TABLE_NAME, this_index.table
      assert_equal 1, this_index.columns.size
      assert_equal this_index_column, this_index.columns[0]
      assert_equal this_index_name, this_index.name
    end
end
