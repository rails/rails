require "cases/helper"

class SchemaTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  SCHEMA_NAME = 'test_schema'
  SCHEMA2_NAME = 'test_schema2'
  TABLE_NAME = 'things'
  CAPITALIZED_TABLE_NAME = 'Things'
  INDEX_A_NAME = 'a_index_things_on_name'
  INDEX_B_NAME = 'b_index_things_on_different_columns_in_each_schema'
  INDEX_C_NAME = 'c_index_full_text_search'
  INDEX_D_NAME = 'd_index_things_on_description_desc'
  INDEX_E_NAME = 'e_index_things_on_name_vector'
  INDEX_A_COLUMN = 'name'
  INDEX_B_COLUMN_S1 = 'email'
  INDEX_B_COLUMN_S2 = 'moment'
  INDEX_C_COLUMN = %q{(to_tsvector('english', coalesce(things.name, '')))}
  INDEX_D_COLUMN = 'description'
  INDEX_E_COLUMN = 'name_vector'
  COLUMNS = [
    'id integer',
    'name character varying(50)',
    'email character varying(50)',
    'description character varying(100)',
    'name_vector tsvector',
    'moment timestamp without time zone default now()'
  ]
  PK_TABLE_NAME = 'table_with_pk'
  UNMATCHED_SEQUENCE_NAME = 'unmatched_primary_key_default_value_seq'
  UNMATCHED_PK_TABLE_NAME = 'table_with_unmatched_sequence_for_pk'

  class Thing1 < ActiveRecord::Base
    self.table_name = "test_schema.things"
  end

  class Thing2 < ActiveRecord::Base
    self.table_name = "test_schema2.things"
  end

  class Thing3 < ActiveRecord::Base
    self.table_name = 'test_schema."things.table"'
  end

  class Thing4 < ActiveRecord::Base
    self.table_name = 'test_schema."Things"'
  end

  class Thing5 < ActiveRecord::Base
    self.table_name = 'things'
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
    @connection.execute "CREATE INDEX #{INDEX_C_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_C_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_C_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_C_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_D_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_D_COLUMN} DESC);"
    @connection.execute "CREATE INDEX #{INDEX_D_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING btree (#{INDEX_D_COLUMN} DESC);"
    @connection.execute "CREATE INDEX #{INDEX_E_NAME} ON #{SCHEMA_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_E_COLUMN});"
    @connection.execute "CREATE INDEX #{INDEX_E_NAME} ON #{SCHEMA2_NAME}.#{TABLE_NAME}  USING gin (#{INDEX_E_COLUMN});"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{PK_TABLE_NAME} (id serial primary key)"
    @connection.execute "CREATE SEQUENCE #{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{UNMATCHED_PK_TABLE_NAME} (id integer NOT NULL DEFAULT nextval('#{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}'::regclass), CONSTRAINT unmatched_pkey PRIMARY KEY (id))"
  end

  def teardown
    @connection.execute "DROP SCHEMA #{SCHEMA2_NAME} CASCADE"
    @connection.execute "DROP SCHEMA #{SCHEMA_NAME} CASCADE"
  end

  def test_schema_names
    assert_equal ["public", "test_schema", "test_schema2"], @connection.schema_names
  end

  def test_create_schema
    begin
      @connection.create_schema "test_schema3"
      assert @connection.schema_names.include? "test_schema3"
    ensure
      @connection.drop_schema "test_schema3"
    end
  end

  def test_raise_create_schema_with_existing_schema
    begin
      @connection.create_schema "test_schema3"
      assert_raises(ActiveRecord::StatementInvalid) do
        @connection.create_schema "test_schema3"
      end
    ensure
      @connection.drop_schema "test_schema3"
    end
  end

  def test_drop_schema
    begin
      @connection.create_schema "test_schema3"
    ensure
      @connection.drop_schema "test_schema3"
    end
    assert !@connection.schema_names.include?("test_schema3")
  end

  def test_raise_drop_schema_with_nonexisting_schema
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.drop_schema "test_schema3"
    end
  end

  def test_schema_change_with_prepared_stmt
    altered = false
    @connection.exec_query "select * from developers where id = $1", 'sql', [[nil, 1]]
    @connection.exec_query "alter table developers add column zomg int", 'sql', []
    altered = true
    @connection.exec_query "select * from developers where id = $1", 'sql', [[nil, 1]]
  ensure
    # We are not using DROP COLUMN IF EXISTS because that syntax is only
    # supported by pg 9.X
    @connection.exec_query("alter table developers drop column zomg", 'sql', []) if altered
  end

  def test_table_exists?
    [Thing1, Thing2, Thing3, Thing4].each do |klass|
      name = klass.table_name
      assert @connection.table_exists?(name), "'#{name}' table should exist"
    end
  end

  def test_table_exists_when_on_schema_search_path
    with_schema_search_path(SCHEMA_NAME) do
      assert(@connection.table_exists?(TABLE_NAME), "table should exist and be found")
    end
  end

  def test_table_exists_when_not_on_schema_search_path
    with_schema_search_path('PUBLIC') do
      assert(!@connection.table_exists?(TABLE_NAME), "table exists but should not be found")
    end
  end

  def test_table_exists_wrong_schema
    assert(!@connection.table_exists?("foo.things"), "table should not exist")
  end

  def test_table_exists_quoted_names
    [ %("#{SCHEMA_NAME}"."#{TABLE_NAME}"), %(#{SCHEMA_NAME}."#{TABLE_NAME}"), %(#{SCHEMA_NAME}."#{TABLE_NAME}")].each do |given|
      assert(@connection.table_exists?(given), "table should exist when specified as #{given}")
    end
    with_schema_search_path(SCHEMA_NAME) do
      given = %("#{TABLE_NAME}")
      assert(@connection.table_exists?(given), "table should exist when specified as #{given}")
    end
  end

  def test_table_exists_quoted_table
    with_schema_search_path(SCHEMA_NAME) do
        assert(@connection.table_exists?('"things.table"'), "table should exist")
    end
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
    assert_raises(ActiveRecord::StatementInvalid) do
      with_schema_search_path '$user,public'
    end
  end

  def test_without_schema_search_path
    assert_raises(ActiveRecord::StatementInvalid) { columns(TABLE_NAME) }
  end

  def test_ignore_nil_schema_search_path
    assert_nothing_raised { with_schema_search_path nil }
  end

  def test_dump_indexes_for_schema_one
    do_dump_index_tests_for_schema(SCHEMA_NAME, INDEX_A_COLUMN, INDEX_B_COLUMN_S1, INDEX_D_COLUMN, INDEX_E_COLUMN)
  end

  def test_dump_indexes_for_schema_two
    do_dump_index_tests_for_schema(SCHEMA2_NAME, INDEX_A_COLUMN, INDEX_B_COLUMN_S2, INDEX_D_COLUMN, INDEX_E_COLUMN)
  end

  def test_dump_indexes_for_schema_multiple_schemas_in_search_path
    do_dump_index_tests_for_schema("public, #{SCHEMA_NAME}", INDEX_A_COLUMN, INDEX_B_COLUMN_S1, INDEX_D_COLUMN, INDEX_E_COLUMN)
  end

  def test_with_uppercase_index_name
    ActiveRecord::Base.connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_nothing_raised { ActiveRecord::Base.connection.remove_index! "things", "#{SCHEMA_NAME}.things_Index"}

    ActiveRecord::Base.connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    ActiveRecord::Base.connection.schema_search_path = SCHEMA_NAME
    assert_nothing_raised { ActiveRecord::Base.connection.remove_index! "things", "things_Index"}
    ActiveRecord::Base.connection.schema_search_path = "public"
  end

  def test_primary_key_with_schema_specified
    [
      %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}"),
      %(#{SCHEMA_NAME}."#{PK_TABLE_NAME}"),
      %(#{SCHEMA_NAME}.#{PK_TABLE_NAME})
    ].each do |given|
      assert_equal 'id', @connection.primary_key(given), "primary key should be found when table referenced as #{given}"
    end
  end

  def test_primary_key_assuming_schema_search_path
    with_schema_search_path(SCHEMA_NAME) do
      assert_equal 'id', @connection.primary_key(PK_TABLE_NAME), "primary key should be found"
    end
  end

  def test_primary_key_raises_error_if_table_not_found_on_schema_search_path
    with_schema_search_path(SCHEMA2_NAME) do
      assert_raises(ActiveRecord::StatementInvalid) do
        @connection.primary_key(PK_TABLE_NAME)
      end
    end
  end

  def test_pk_and_sequence_for_with_schema_specified
    [
      %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}"),
      %("#{SCHEMA_NAME}"."#{UNMATCHED_PK_TABLE_NAME}")
    ].each do |given|
      pk, seq = @connection.pk_and_sequence_for(given)
      assert_equal 'id', pk, "primary key should be found when table referenced as #{given}"
      assert_equal "#{PK_TABLE_NAME}_id_seq", seq, "sequence name should be found when table referenced as #{given}" if given == %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}")
      assert_equal "#{UNMATCHED_SEQUENCE_NAME}", seq, "sequence name should be found when table referenced as #{given}" if given ==  %("#{SCHEMA_NAME}"."#{UNMATCHED_PK_TABLE_NAME}")
    end
  end

  def test_current_schema
    {
      %('$user',public)                        => 'public',
      SCHEMA_NAME                              => SCHEMA_NAME,
      %(#{SCHEMA2_NAME},#{SCHEMA_NAME},public) => SCHEMA2_NAME,
      %(public,#{SCHEMA2_NAME},#{SCHEMA_NAME}) => 'public'
    }.each do |given,expect|
      with_schema_search_path(given) { assert_equal expect, @connection.current_schema }
    end
  end

  def test_prepared_statements_with_multiple_schemas

    @connection.schema_search_path = SCHEMA_NAME
    Thing5.create(:id => 1, :name => "thing inside #{SCHEMA_NAME}", :email => "thing1@localhost", :moment => Time.now)

    @connection.schema_search_path = SCHEMA2_NAME
    Thing5.create(:id => 1, :name => "thing inside #{SCHEMA2_NAME}", :email => "thing1@localhost", :moment => Time.now)

    @connection.schema_search_path = SCHEMA_NAME
    assert_equal 1, Thing5.count

    @connection.schema_search_path = SCHEMA2_NAME
    assert_equal 1, Thing5.count
  end

  def test_schema_exists?
    {
      'public'     => true,
      SCHEMA_NAME  => true,
      SCHEMA2_NAME => true,
      'darkside'   => false
    }.each do |given,expect|
      assert_equal expect, @connection.schema_exists?(given)
    end
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

    def do_dump_index_tests_for_schema(this_schema_name, first_index_column_name, second_index_column_name, third_index_column_name, fourth_index_column_name)
      with_schema_search_path(this_schema_name) do
        indexes = @connection.indexes(TABLE_NAME).sort_by {|i| i.name}
        assert_equal 4,indexes.size

        do_dump_index_assertions_for_one_index(indexes[0], INDEX_A_NAME, first_index_column_name)
        do_dump_index_assertions_for_one_index(indexes[1], INDEX_B_NAME, second_index_column_name)
        do_dump_index_assertions_for_one_index(indexes[2], INDEX_D_NAME, third_index_column_name)
        do_dump_index_assertions_for_one_index(indexes[3], INDEX_E_NAME, fourth_index_column_name)

        indexes.select{|i| i.name != INDEX_E_NAME}.each do |index|
           assert_equal :btree, index.type
        end
        assert_equal :gin, indexes.select{|i| i.name == INDEX_E_NAME}[0].type
        assert_equal :desc, indexes.select{|i| i.name == INDEX_D_NAME}[0].orders[INDEX_D_COLUMN]
      end
    end

    def do_dump_index_assertions_for_one_index(this_index, this_index_name, this_index_column)
      assert_equal TABLE_NAME, this_index.table
      assert_equal 1, this_index.columns.size
      assert_equal this_index_column, this_index.columns[0]
      assert_equal this_index_name, this_index.name
    end
end
