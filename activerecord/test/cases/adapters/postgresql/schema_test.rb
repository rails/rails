# frozen_string_literal: true

require "cases/helper"
require "models/default"
require "support/schema_dumping_helper"

module PGSchemaHelper
  def with_schema_search_path(schema_search_path)
    @connection.schema_search_path = schema_search_path
    @connection.schema_cache.clear!
    yield if block_given?
  ensure
    @connection.schema_search_path = "'$user', public"
    @connection.schema_cache.clear!
  end
end

class SchemaTest < ActiveRecord::PostgreSQLTestCase
  include PGSchemaHelper
  self.use_transactional_tests = false

  SCHEMA_NAME = "test_schema"
  SCHEMA2_NAME = "test_schema2"
  TABLE_NAME = "things"
  CAPITALIZED_TABLE_NAME = "Things"
  INDEX_A_NAME = "a_index_things_on_name"
  INDEX_B_NAME = "b_index_things_on_different_columns_in_each_schema"
  INDEX_C_NAME = "c_index_full_text_search"
  INDEX_D_NAME = "d_index_things_on_description_desc"
  INDEX_E_NAME = "e_index_things_on_name_vector"
  INDEX_A_COLUMN = "name"
  INDEX_B_COLUMN_S1 = "email"
  INDEX_B_COLUMN_S2 = "moment"
  INDEX_C_COLUMN = "(to_tsvector('english', coalesce(things.name, '')))"
  INDEX_D_COLUMN = "description"
  INDEX_E_COLUMN = "name_vector"
  COLUMNS = [
    "id integer",
    "name character varying(50)",
    "email character varying(50)",
    "description character varying(100)",
    "name_vector tsvector",
    "moment timestamp without time zone default now()"
  ]
  PK_TABLE_NAME = "table_with_pk"
  UNMATCHED_SEQUENCE_NAME = "unmatched_primary_key_default_value_seq"
  UNMATCHED_PK_TABLE_NAME = "table_with_unmatched_sequence_for_pk"
  PARTITIONED_TABLE = "measurements"
  PARTITIONED_TABLE_INDEX = "index_measurements_on_logdate_and_city_id"

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
    self.table_name = "things"
  end

  class Song < ActiveRecord::Base
    self.table_name = "music.songs"
    has_and_belongs_to_many :albums
  end

  class Album < ActiveRecord::Base
    self.table_name = "music.albums"
    has_and_belongs_to_many :songs
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
    @connection.execute "CREATE TABLE #{SCHEMA2_NAME}.#{PK_TABLE_NAME} (id serial primary key)"
    @connection.execute "CREATE SEQUENCE #{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}"
    @connection.execute "CREATE TABLE #{SCHEMA_NAME}.#{UNMATCHED_PK_TABLE_NAME} (id integer NOT NULL DEFAULT nextval('#{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}'::regclass), CONSTRAINT unmatched_pkey PRIMARY KEY (id))"
  end

  teardown do
    @connection.drop_schema SCHEMA2_NAME, if_exists: true
    @connection.drop_schema SCHEMA_NAME, if_exists: true
  end

  def test_schema_names
    schema_names = @connection.schema_names
    assert_includes schema_names, "public"
    assert_includes schema_names, "test_schema"
    assert_includes schema_names, "test_schema2"
    assert_includes schema_names, "hint_plan" if @connection.supports_optimizer_hints?
  end

  def test_create_schema
    @connection.create_schema "test_schema3"
    assert @connection.schema_names.include? "test_schema3"
  ensure
    @connection.drop_schema "test_schema3"
  end

  def test_raise_create_schema_with_existing_schema
    @connection.create_schema "test_schema3"
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.create_schema "test_schema3"
    end
  ensure
    @connection.drop_schema "test_schema3"
  end

  def test_drop_schema
    @connection.create_schema "test_schema3"
    @connection.drop_schema "test_schema3"
    assert_not_includes @connection.schema_names, "test_schema3"
  end

  def test_drop_schema_if_exists
    @connection.create_schema "some_schema"
    assert_includes @connection.schema_names, "some_schema"
    @connection.drop_schema "some_schema", if_exists: true
    assert_not_includes @connection.schema_names, "some_schema"
  end

  def test_habtm_table_name_with_schema
    ActiveRecord::Base.connection.drop_schema "music", if_exists: true
    ActiveRecord::Base.connection.create_schema "music"
    ActiveRecord::Base.connection.execute <<~SQL
      CREATE TABLE music.albums (id serial primary key);
      CREATE TABLE music.songs (id serial primary key);
      CREATE TABLE music.albums_songs (album_id integer, song_id integer);
    SQL

    song = Song.create
    Album.create
    assert_equal song, Song.includes(:albums).references(:albums).first
  ensure
    ActiveRecord::Base.connection.drop_schema "music", if_exists: true
  end

  def test_drop_schema_with_nonexisting_schema
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.drop_schema "idontexist"
    end

    assert_nothing_raised do
      @connection.drop_schema "idontexist", if_exists: true
    end
  end

  def test_raise_wrapped_exception_on_bad_prepare
    assert_raises(ActiveRecord::StatementInvalid) do
      @connection.exec_query "select * from developers where id = ?", "sql", [bind_param(1)]
    end
  end

  if ActiveRecord::Base.connection.prepared_statements
    def test_schema_change_with_prepared_stmt
      altered = false
      @connection.exec_query "select * from developers where id = $1", "sql", [bind_param(1)]
      @connection.exec_query "alter table developers add column zomg int", "sql", []
      altered = true
      @connection.exec_query "select * from developers where id = $1", "sql", [bind_param(1)]
    ensure
      # We are not using DROP COLUMN IF EXISTS because that syntax is only
      # supported by pg 9.X
      @connection.exec_query("alter table developers drop column zomg", "sql", []) if altered
    end
  end

  def test_data_source_exists?
    [Thing1, Thing2, Thing3, Thing4].each do |klass|
      name = klass.table_name
      assert @connection.data_source_exists?(name), "'#{name}' data_source should exist"
    end
  end

  def test_data_source_exists_when_on_schema_search_path
    with_schema_search_path(SCHEMA_NAME) do
      assert(@connection.data_source_exists?(TABLE_NAME), "data_source should exist and be found")
    end
  end

  def test_data_source_exists_when_not_on_schema_search_path
    with_schema_search_path("PUBLIC") do
      assert_not(@connection.data_source_exists?(TABLE_NAME), "data_source exists but should not be found")
    end
  end

  def test_data_source_exists_wrong_schema
    assert_not(@connection.data_source_exists?("foo.things"), "data_source should not exist")
  end

  def test_data_source_exists_quoted_names
    [ %("#{SCHEMA_NAME}"."#{TABLE_NAME}"), %(#{SCHEMA_NAME}."#{TABLE_NAME}"), %(#{SCHEMA_NAME}."#{TABLE_NAME}")].each do |given|
      assert(@connection.data_source_exists?(given), "data_source should exist when specified as #{given}")
    end
    with_schema_search_path(SCHEMA_NAME) do
      given = %("#{TABLE_NAME}")
      assert(@connection.data_source_exists?(given), "data_source should exist when specified as #{given}")
    end
  end

  def test_data_source_exists_quoted_table
    with_schema_search_path(SCHEMA_NAME) do
      assert(@connection.data_source_exists?('"things.table"'), "data_source should exist")
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
    assert_equal '"table_name"', @connection.quote_table_name("table_name")
    assert_equal '"table.name"', @connection.quote_table_name('"table.name"')
    assert_equal '"schema_name"."table_name"', @connection.quote_table_name("schema_name.table_name")
    assert_equal '"schema_name"."table.name"', @connection.quote_table_name('schema_name."table.name"')
    assert_equal '"schema.name"."table_name"', @connection.quote_table_name('"schema.name".table_name')
    assert_equal '"schema.name"."table.name"', @connection.quote_table_name('"schema.name"."table.name"')
  end

  def test_classes_with_qualified_schema_name
    assert_equal 0, Thing1.count
    assert_equal 0, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing1.create(id: 1, name: "thing1", email: "thing1@localhost", moment: Time.now)
    assert_equal 1, Thing1.count
    assert_equal 0, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing2.create(id: 1, name: "thing1", email: "thing1@localhost", moment: Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 0, Thing3.count
    assert_equal 0, Thing4.count

    Thing3.create(id: 1, name: "thing1", email: "thing1@localhost", moment: Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 1, Thing3.count
    assert_equal 0, Thing4.count

    Thing4.create(id: 1, name: "thing1", email: "thing1@localhost", moment: Time.now)
    assert_equal 1, Thing1.count
    assert_equal 1, Thing2.count
    assert_equal 1, Thing3.count
    assert_equal 1, Thing4.count
  end

  def test_raise_on_unquoted_schema_name
    assert_raises(ActiveRecord::StatementInvalid) do
      with_schema_search_path "$user,public"
    end
  end

  def test_without_schema_search_path
    assert_raises(ActiveRecord::StatementInvalid) { columns(TABLE_NAME) }
  end

  def test_ignore_nil_schema_search_path
    assert_nothing_raised { with_schema_search_path nil }
  end

  def test_index_name_exists
    with_schema_search_path(SCHEMA_NAME) do
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_A_NAME)
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_B_NAME)
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_C_NAME)
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_D_NAME)
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_E_NAME)
      assert @connection.index_name_exists?(TABLE_NAME, INDEX_E_NAME)
      assert_not @connection.index_name_exists?(TABLE_NAME, "missing_index")

      if supports_partitioned_indexes?
        create_partitioned_table
        create_partitioned_table_index
        assert @connection.index_name_exists?(PARTITIONED_TABLE, PARTITIONED_TABLE_INDEX)
      end
    end
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

  def test_dump_indexes_for_table_with_scheme_specified_in_name
    indexes = @connection.indexes("#{SCHEMA_NAME}.#{TABLE_NAME}")
    assert_equal 5, indexes.size

    if supports_partitioned_indexes?
      create_partitioned_table
      create_partitioned_table_index
      indexes = @connection.indexes("#{SCHEMA_NAME}.#{PARTITIONED_TABLE}")
      assert_equal 1, indexes.size
    end
  end

  def test_with_uppercase_index_name
    @connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"

    with_schema_search_path SCHEMA_NAME do
      assert_nothing_raised { @connection.remove_index "things", name: "things_Index" }
    end

    if supports_partitioned_indexes?
      create_partitioned_table
      @connection.execute "CREATE INDEX \"#{PARTITIONED_TABLE}_Index\" ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"

      with_schema_search_path SCHEMA_NAME do
        assert_nothing_raised { @connection.remove_index PARTITIONED_TABLE, name: "#{PARTITIONED_TABLE}_Index" }
      end
    end
  end

  def test_remove_index_when_schema_specified
    @connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_nothing_raised { @connection.remove_index "things", name: "#{SCHEMA_NAME}.things_Index" }

    @connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_nothing_raised { @connection.remove_index "#{SCHEMA_NAME}.things", name: "things_Index" }

    @connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_nothing_raised { @connection.remove_index "#{SCHEMA_NAME}.things", name: "#{SCHEMA_NAME}.things_Index" }

    @connection.execute "CREATE INDEX \"things_Index\" ON #{SCHEMA_NAME}.things (name)"
    assert_raises(ArgumentError) { @connection.remove_index "#{SCHEMA2_NAME}.things", name: "#{SCHEMA_NAME}.things_Index" }

    if supports_partitioned_indexes?
      create_partitioned_table

      @connection.execute "CREATE INDEX \"#{PARTITIONED_TABLE}_Index\" ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"
      assert_nothing_raised { @connection.remove_index PARTITIONED_TABLE, name: "#{SCHEMA_NAME}.#{PARTITIONED_TABLE}_Index" }

      @connection.execute "CREATE INDEX \"#{PARTITIONED_TABLE}_Index\" ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"
      assert_nothing_raised { @connection.remove_index "#{SCHEMA_NAME}.#{PARTITIONED_TABLE}", name: "#{PARTITIONED_TABLE}_Index" }

      @connection.execute "CREATE INDEX \"#{PARTITIONED_TABLE}_Index\" ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"
      assert_nothing_raised { @connection.remove_index "#{SCHEMA_NAME}.#{PARTITIONED_TABLE}", name: "#{SCHEMA_NAME}.#{PARTITIONED_TABLE}_Index" }

      @connection.execute "CREATE INDEX \"#{PARTITIONED_TABLE}_Index\" ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"
      assert_raises(ArgumentError) { @connection.remove_index "#{SCHEMA2_NAME}.#{PARTITIONED_TABLE}", name: "#{SCHEMA_NAME}.#{PARTITIONED_TABLE}_Index" }
    end
  end

  def test_primary_key_with_schema_specified
    [
      %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}"),
      %(#{SCHEMA_NAME}."#{PK_TABLE_NAME}"),
      %(#{SCHEMA_NAME}.#{PK_TABLE_NAME})
    ].each do |given|
      assert_equal "id", @connection.primary_key(given), "primary key should be found when table referenced as #{given}"
    end
  end

  def test_primary_key_assuming_schema_search_path
    with_schema_search_path("#{SCHEMA_NAME}, #{SCHEMA2_NAME}") do
      assert_equal "id", @connection.primary_key(PK_TABLE_NAME), "primary key should be found"
    end
  end

  def test_pk_and_sequence_for_with_schema_specified
    pg_name = ActiveRecord::ConnectionAdapters::PostgreSQL::Name
    [
      %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}"),
      %("#{SCHEMA_NAME}"."#{UNMATCHED_PK_TABLE_NAME}")
    ].each do |given|
      pk, seq = @connection.pk_and_sequence_for(given)
      assert_equal "id", pk, "primary key should be found when table referenced as #{given}"
      assert_equal pg_name.new(SCHEMA_NAME, "#{PK_TABLE_NAME}_id_seq"), seq, "sequence name should be found when table referenced as #{given}" if given == %("#{SCHEMA_NAME}"."#{PK_TABLE_NAME}")
      assert_equal pg_name.new(SCHEMA_NAME, UNMATCHED_SEQUENCE_NAME), seq, "sequence name should be found when table referenced as #{given}" if given == %("#{SCHEMA_NAME}"."#{UNMATCHED_PK_TABLE_NAME}")
    end
  end

  def test_current_schema
    {
      %('$user',public)                        => "public",
      SCHEMA_NAME                              => SCHEMA_NAME,
      %(#{SCHEMA2_NAME},#{SCHEMA_NAME},public) => SCHEMA2_NAME,
      %(public,#{SCHEMA2_NAME},#{SCHEMA_NAME}) => "public"
    }.each do |given, expect|
      with_schema_search_path(given) { assert_equal expect, @connection.current_schema }
    end
  end

  def test_prepared_statements_with_multiple_schemas
    [SCHEMA_NAME, SCHEMA2_NAME].each do |schema_name|
      with_schema_search_path schema_name do
        Thing5.create(id: 1, name: "thing inside #{SCHEMA_NAME}", email: "thing1@localhost", moment: Time.now)
      end
    end

    [SCHEMA_NAME, SCHEMA2_NAME].each do |schema_name|
      with_schema_search_path schema_name do
        assert_equal 1, Thing5.count
      end
    end
  end

  def test_schema_exists?
    {
      "public"     => true,
      SCHEMA_NAME  => true,
      SCHEMA2_NAME => true,
      "darkside"   => false
    }.each do |given, expect|
      assert_equal expect, @connection.schema_exists?(given)
    end
  end

  def test_reset_pk_sequence
    sequence_name = "#{SCHEMA_NAME}.#{UNMATCHED_SEQUENCE_NAME}"
    @connection.execute "SELECT setval('#{sequence_name}', 123)"
    assert_equal 124, @connection.select_value("SELECT nextval('#{sequence_name}')")
    @connection.reset_pk_sequence!("#{SCHEMA_NAME}.#{UNMATCHED_PK_TABLE_NAME}")
    assert_equal 1, @connection.select_value("SELECT nextval('#{sequence_name}')")
  end

  def test_set_pk_sequence
    table_name = "#{SCHEMA_NAME}.#{PK_TABLE_NAME}"
    _, sequence_name = @connection.pk_and_sequence_for table_name
    @connection.set_pk_sequence! table_name, 123
    assert_equal 124, @connection.select_value("SELECT nextval('#{sequence_name}')")
    @connection.reset_pk_sequence! table_name
  end

  private
    def columns(table_name)
      @connection.send(:column_definitions, table_name).map do |name, type, default|
        "#{name} #{type}" + (default ? " default #{default}" : "")
      end
    end

    def do_dump_index_tests_for_schema(this_schema_name, first_index_column_name, second_index_column_name, third_index_column_name, fourth_index_column_name)
      with_schema_search_path(this_schema_name) do
        indexes = @connection.indexes(TABLE_NAME).sort_by(&:name)
        assert_equal 5, indexes.size

        index_a, index_b, index_c, index_d, index_e = indexes

        do_dump_index_assertions_for_one_index(index_a, INDEX_A_NAME, first_index_column_name)
        do_dump_index_assertions_for_one_index(index_b, INDEX_B_NAME, second_index_column_name)
        do_dump_index_assertions_for_one_index(index_d, INDEX_D_NAME, third_index_column_name)
        do_dump_index_assertions_for_one_index(index_e, INDEX_E_NAME, fourth_index_column_name)

        assert_equal :btree, index_a.using
        assert_equal :btree, index_b.using
        assert_equal :gin,   index_c.using
        assert_equal :btree, index_d.using
        assert_equal :gin,   index_e.using

        assert_equal :desc,  index_d.orders
      end
    end

    def do_dump_index_assertions_for_one_index(this_index, this_index_name, this_index_column)
      assert_equal TABLE_NAME, this_index.table
      assert_equal 1, this_index.columns.size
      assert_equal this_index_column, this_index.columns[0]
      assert_equal this_index_name, this_index.name
    end

    def bind_param(value)
      ActiveRecord::Relation::QueryAttribute.new(nil, value, ActiveRecord::Type::Value.new)
    end

    def create_partitioned_table
      @connection.execute "CREATE TABLE #{SCHEMA_NAME}.\"#{PARTITIONED_TABLE}\" (city_id integer not null, logdate date not null) PARTITION BY LIST (city_id)"
    end

    def create_partitioned_table_index
      @connection.execute "CREATE INDEX #{PARTITIONED_TABLE_INDEX} ON #{SCHEMA_NAME}.#{PARTITIONED_TABLE} (logdate, city_id)"
    end
end

class SchemaForeignKeyTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.connection
  end

  def test_dump_foreign_key_targeting_different_schema
    @connection.create_schema "my_schema"
    @connection.create_table "my_schema.trains" do |t|
      t.string :name
    end
    @connection.create_table "wagons" do |t|
      t.integer :train_id
    end
    @connection.add_foreign_key "wagons", "my_schema.trains", column: "train_id"
    output = dump_table_schema "wagons"
    assert_match %r{\s+add_foreign_key "wagons", "my_schema\.trains", column: "train_id"$}, output
  ensure
    @connection.drop_table "wagons", if_exists: true
    @connection.drop_table "my_schema.trains", if_exists: true
    @connection.drop_schema "my_schema", if_exists: true
  end
end

class SchemaIndexOpclassTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table "trains" do |t|
      t.string :name
      t.string :position
      t.text :description
    end
  end

  teardown do
    @connection.drop_table "trains", if_exists: true
  end

  def test_string_opclass_is_dumped
    @connection.execute "CREATE INDEX trains_name_and_description ON trains USING btree(name text_pattern_ops, description text_pattern_ops)"

    output = dump_table_schema "trains"

    assert_match(/opclass: :text_pattern_ops/, output)
  end

  def test_non_default_opclass_is_dumped
    @connection.execute "CREATE INDEX trains_name_and_description ON trains USING btree(name, description text_pattern_ops)"

    output = dump_table_schema "trains"

    assert_match(/opclass: \{ description: :text_pattern_ops \}/, output)
  end

  def test_opclass_class_parsing_on_non_reserved_and_cannot_be_function_or_type_keyword
    @connection.enable_extension("pg_trgm")
    @connection.execute "CREATE INDEX trains_position ON trains USING gin(position gin_trgm_ops)"
    @connection.execute "CREATE INDEX trains_name_and_position ON trains USING btree(name, position text_pattern_ops)"

    output = dump_table_schema "trains"

    assert_match(/opclass: :gin_trgm_ops/, output)
    assert_match(/opclass: \{ position: :text_pattern_ops \}/, output)
  end
end

class SchemaIndexNullsOrderTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table "trains" do |t|
      t.string :name
      t.text :description
    end
  end

  teardown do
    @connection.drop_table "trains", if_exists: true
  end

  def test_nulls_order_is_dumped
    @connection.execute "CREATE INDEX trains_name_and_description ON trains USING btree(name NULLS FIRST, description)"
    output = dump_table_schema "trains"
    assert_match(/order: \{ name: "NULLS FIRST" \}/, output)
  end

  def test_non_default_order_with_nulls_is_dumped
    @connection.execute "CREATE INDEX trains_name_and_desc ON trains USING btree(name DESC NULLS LAST, description)"
    output = dump_table_schema "trains"
    assert_match(/order: \{ name: "DESC NULLS LAST" \}/, output)
  end
end

class DefaultsUsingMultipleSchemasAndDomainTest < ActiveRecord::PostgreSQLTestCase
  setup do
    @connection = ActiveRecord::Base.connection
    @connection.drop_schema "schema_1", if_exists: true
    @connection.execute "CREATE SCHEMA schema_1"
    @connection.execute "CREATE DOMAIN schema_1.text AS text"
    @connection.execute "CREATE DOMAIN schema_1.varchar AS varchar"
    @connection.execute "CREATE DOMAIN schema_1.bpchar AS bpchar"

    @old_search_path = @connection.schema_search_path
    @connection.schema_search_path = "schema_1, pg_catalog"
    @connection.create_table "defaults" do |t|
      t.text "text_col", default: "some value"
      t.string "string_col", default: "some value"
      t.decimal "decimal_col", default: "3.14159265358979323846"
    end
    Default.reset_column_information
  end

  teardown do
    @connection.schema_search_path = @old_search_path
    @connection.drop_schema "schema_1", if_exists: true
    Default.reset_column_information
  end

  def test_text_defaults_in_new_schema_when_overriding_domain
    assert_equal "some value", Default.new.text_col, "Default of text column was not correctly parsed"
  end

  def test_string_defaults_in_new_schema_when_overriding_domain
    assert_equal "some value", Default.new.string_col, "Default of string column was not correctly parsed"
  end

  def test_decimal_defaults_in_new_schema_when_overriding_domain
    assert_equal BigDecimal("3.14159265358979323846"), Default.new.decimal_col, "Default of decimal column was not correctly parsed"
  end

  def test_bpchar_defaults_in_new_schema_when_overriding_domain
    @connection.execute "ALTER TABLE defaults ADD bpchar_col bpchar DEFAULT 'some value'"
    Default.reset_column_information
    assert_equal "some value", Default.new.bpchar_col, "Default of bpchar column was not correctly parsed"
  end

  def test_text_defaults_after_updating_column_default
    @connection.execute "ALTER TABLE defaults ALTER COLUMN text_col SET DEFAULT 'some text'::schema_1.text"
    assert_equal "some text", Default.new.text_col, "Default of text column was not correctly parsed after updating default using '::text' since postgreSQL will add parens to the default in db"
  end

  def test_default_containing_quote_and_colons
    @connection.execute "ALTER TABLE defaults ALTER COLUMN string_col SET DEFAULT 'foo''::bar'"
    assert_equal "foo'::bar", Default.new.string_col
  end
end

class SchemaWithDotsTest < ActiveRecord::PostgreSQLTestCase
  include PGSchemaHelper
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_schema "my.schema"
  end

  teardown do
    @connection.drop_schema "my.schema", if_exists: true
  end

  test "rename_table" do
    with_schema_search_path('"my.schema"') do
      @connection.create_table :posts
      @connection.rename_table :posts, :articles
      assert_equal ["articles"], @connection.tables
    end
  end

  test "Active Record basics" do
    with_schema_search_path('"my.schema"') do
      @connection.create_table :articles do |t|
        t.string :title
      end
      article_class = Class.new(ActiveRecord::Base) do
        self.table_name = '"my.schema".articles'
      end

      article_class.create!(title: "zOMG, welcome to my blorgh!")
      welcome_article = article_class.last
      assert_equal "zOMG, welcome to my blorgh!", welcome_article.title
    end
  end
end
