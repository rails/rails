# frozen_string_literal: true

require 'cases/helper'
require 'support/schema_dumping_helper'

module PostgresqlUUIDHelper
  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def drop_table(name)
    connection.drop_table name, if_exists: true
  end

  def uuid_function
    connection.supports_pgcrypto_uuid? ? 'gen_random_uuid()' : 'uuid_generate_v4()'
  end

  def uuid_default
    connection.supports_pgcrypto_uuid? ? {} : { default: uuid_function }
  end
end

class PostgresqlUUIDTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlUUIDHelper
  include SchemaDumpingHelper

  class UUIDType < ActiveRecord::Base
    self.table_name = 'uuid_data_type'
  end

  setup do
    enable_extension!('uuid-ossp', connection)
    enable_extension!('pgcrypto',  connection) if connection.supports_pgcrypto_uuid?

    connection.create_table 'uuid_data_type' do |t|
      t.uuid 'guid'
    end
  end

  teardown do
    drop_table 'uuid_data_type'
  end

  if ActiveRecord::Base.connection.respond_to?(:supports_pgcrypto_uuid?) &&
      ActiveRecord::Base.connection.supports_pgcrypto_uuid?
    def test_uuid_column_default
      connection.add_column :uuid_data_type, :thingy, :uuid, null: false, default: 'gen_random_uuid()'
      UUIDType.reset_column_information
      column = UUIDType.columns_hash['thingy']
      assert_equal 'gen_random_uuid()', column.default_function
    end
  end

  def test_change_column_default
    connection.add_column :uuid_data_type, :thingy, :uuid, null: false, default: 'uuid_generate_v1()'
    UUIDType.reset_column_information
    column = UUIDType.columns_hash['thingy']
    assert_equal 'uuid_generate_v1()', column.default_function

    connection.change_column :uuid_data_type, :thingy, :uuid, null: false, default: 'uuid_generate_v4()'
    UUIDType.reset_column_information
    column = UUIDType.columns_hash['thingy']
    assert_equal 'uuid_generate_v4()', column.default_function
  ensure
    UUIDType.reset_column_information
  end

  def test_add_column_with_null_true_and_default_nil
    connection.add_column :uuid_data_type, :thingy, :uuid, null: true, default: nil

    UUIDType.reset_column_information
    column = UUIDType.columns_hash['thingy']

    assert column.null
    assert_nil column.default
  end

  def test_add_column_with_default_array
    connection.add_column :uuid_data_type, :thingy, :uuid, array: true, default: []

    UUIDType.reset_column_information
    column = UUIDType.columns_hash['thingy']

    assert_predicate column, :array?
    assert_equal '{}', column.default

    schema = dump_table_schema 'uuid_data_type'
    assert_match %r{t\.uuid "thingy", default: \[\], array: true$}, schema
  end

  def test_data_type_of_uuid_types
    column = UUIDType.columns_hash['guid']
    assert_equal :uuid, column.type
    assert_equal 'uuid', column.sql_type
    assert_not_predicate column, :array?

    type = UUIDType.type_for_attribute('guid')
    assert_not_predicate type, :binary?
  end

  def test_treat_blank_uuid_as_nil
    UUIDType.create! guid: ''
    assert_nil(UUIDType.last.guid)
  end

  def test_treat_invalid_uuid_as_nil
    uuid = UUIDType.create! guid: 'foobar'
    assert_nil(uuid.guid)
  end

  def test_invalid_uuid_dont_modify_before_type_cast
    uuid = UUIDType.new guid: 'foobar'
    assert_equal 'foobar', uuid.guid_before_type_cast
  end

  def test_invalid_uuid_dont_match_to_nil
    UUIDType.create!
    assert_empty UUIDType.where(guid: '')
    assert_empty UUIDType.where(guid: 'foobar')
  end

  def test_uuid_change_case_does_not_mark_dirty
    model = UUIDType.create!(guid: 'abcd-0123-4567-89ef-dead-beef-0101-1010')
    model.guid = model.guid.swapcase
    assert_not_predicate model, :changed?
  end

  class DuckUUID
    def initialize(uuid)
      @uuid = uuid
    end

    def to_s
      @uuid
    end
  end

  def test_acceptable_uuid_regex
    # Valid uuids
    ['A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11',
     '{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}',
     'a0eebc999c0b4ef8bb6d6bb9bd380a11',
     'a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11',
     '{a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}',
     # The following is not a valid RFC 4122 UUID, but PG doesn't seem to care,
     # so we shouldn't block it either. (Pay attention to "fb6d" – the "f" here
     # is invalid – it must be one of 8, 9, A, B, a, b according to the spec.)
     '{a0eebc99-9c0b-4ef8-fb6d-6bb9bd380a11}',
     # Support Object-Oriented UUIDs which respond to #to_s
     DuckUUID.new('A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'),
    ].each do |valid_uuid|
      uuid = UUIDType.new guid: valid_uuid
      assert_instance_of String, uuid.guid
    end

    # Invalid uuids
    [['A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11'],
     Hash.new,
     0,
     0.0,
     true,
     'Z0000C99-9C0B-4EF8-BB6D-6BB9BD380A11',
     'a0eebc999r0b4ef8ab6d6bb9bd380a11',
     'a0ee-bc99------4ef8-bb6d-6bb9-bd38-0a11',
     '{a0eebc99-bb6d6bb9-bd380a11}',
     '{a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11',
     'a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}'].each do |invalid_uuid|
      uuid = UUIDType.new guid: invalid_uuid
      assert_nil uuid.guid
    end
  end

  def test_uuid_formats
    ['A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11',
     '{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}',
     'a0eebc999c0b4ef8bb6d6bb9bd380a11',
     'a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11',
     '{a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}'].each do |valid_uuid|
      UUIDType.create(guid: valid_uuid)
      uuid = UUIDType.last
      assert_equal 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11', uuid.guid
    end
  end

  def test_schema_dump_with_shorthand
    output = dump_table_schema 'uuid_data_type'
    assert_match %r{t\.uuid "guid"}, output
  end

  def test_uniqueness_validation_ignores_uuid
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = 'uuid_data_type'
      validates :guid, uniqueness: { case_sensitive: false }

      def self.name
        'UUIDType'
      end
    end

    record = klass.create!(guid: 'a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11')
    duplicate = klass.new(guid: record.guid)

    assert record.guid.present? # Ensure we actually are testing a UUID
    assert_not_predicate duplicate, :valid?
  end
end

class PostgresqlUUIDGenerationTest < ActiveRecord::PostgreSQLTestCase
  include PostgresqlUUIDHelper
  include SchemaDumpingHelper

  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  setup do
    connection.create_table('pg_uuids', id: :uuid, default: 'uuid_generate_v1()') do |t|
      t.string 'name'
      t.uuid 'other_uuid', default: 'uuid_generate_v4()'
    end

    # Create custom PostgreSQL function to generate UUIDs
    # to test dumping tables which columns have defaults with custom functions
    connection.execute <<~SQL
      CREATE OR REPLACE FUNCTION my_uuid_generator() RETURNS uuid
      AS $$ SELECT * FROM #{uuid_function} $$
      LANGUAGE SQL VOLATILE;
    SQL

    # Create such a table with custom function as default value generator
    connection.create_table('pg_uuids_2', id: :uuid, default: 'my_uuid_generator()') do |t|
      t.string 'name'
      t.uuid 'other_uuid_2', default: 'my_uuid_generator()'
    end

    connection.create_table('pg_uuids_3', id: :uuid, **uuid_default) do |t|
      t.string 'name'
    end
  end

  teardown do
    drop_table 'pg_uuids'
    drop_table 'pg_uuids_2'
    drop_table 'pg_uuids_3'
    connection.execute 'DROP FUNCTION IF EXISTS my_uuid_generator();'
  end

  def test_id_is_uuid
    assert_equal :uuid, UUID.columns_hash['id'].type
    assert UUID.primary_key
  end

  def test_id_has_a_default
    u = UUID.create
    assert_not_nil u.id
  end

  def test_auto_create_uuid
    u = UUID.create
    u.reload
    assert_not_nil u.other_uuid
  end

  def test_pk_and_sequence_for_uuid_primary_key
    pk, seq = connection.pk_and_sequence_for('pg_uuids')
    assert_equal 'id', pk
    assert_nil seq
  end

  def test_schema_dumper_for_uuid_primary_key
    schema = dump_table_schema 'pg_uuids'
    assert_match(/\bcreate_table "pg_uuids", id: :uuid, default: -> { "uuid_generate_v1\(\)" }/, schema)
    assert_match(/t\.uuid "other_uuid", default: -> { "uuid_generate_v4\(\)" }/, schema)
  end

  def test_schema_dumper_for_uuid_primary_key_with_custom_default
    schema = dump_table_schema 'pg_uuids_2'
    assert_match(/\bcreate_table "pg_uuids_2", id: :uuid, default: -> { "my_uuid_generator\(\)" }/, schema)
    assert_match(/t\.uuid "other_uuid_2", default: -> { "my_uuid_generator\(\)" }/, schema)
  end

  def test_schema_dumper_for_uuid_primary_key_default
    schema = dump_table_schema 'pg_uuids_3'
    if connection.supports_pgcrypto_uuid?
      assert_match(/\bcreate_table "pg_uuids_3", id: :uuid, default: -> { "gen_random_uuid\(\)" }/, schema)
    else
      assert_match(/\bcreate_table "pg_uuids_3", id: :uuid, default: -> { "uuid_generate_v4\(\)" }/, schema)
    end
  end

  def test_schema_dumper_for_uuid_primary_key_default_in_legacy_migration
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    migration = Class.new(ActiveRecord::Migration[5.0]) do
      def version; 101 end
      def migrate(x)
        create_table('pg_uuids_4', id: :uuid)
      end
    end.new
    ActiveRecord::Migrator.new(:up, [migration], ActiveRecord::Base.connection.schema_migration).migrate

    schema = dump_table_schema 'pg_uuids_4'
    assert_match(/\bcreate_table "pg_uuids_4", id: :uuid, default: -> { "uuid_generate_v4\(\)" }/, schema)
  ensure
    drop_table 'pg_uuids_4'
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Base.connection.schema_migration.delete_all
  end
  uses_transaction :test_schema_dumper_for_uuid_primary_key_default_in_legacy_migration
end

class PostgresqlUUIDTestNilDefault < ActiveRecord::PostgreSQLTestCase
  include PostgresqlUUIDHelper
  include SchemaDumpingHelper

  setup do
    connection.create_table('pg_uuids', id: false) do |t|
      t.primary_key :id, :uuid, default: nil
      t.string 'name'
    end
  end

  teardown do
    drop_table 'pg_uuids'
  end

  def test_id_allows_default_override_via_nil
    col_desc = connection.execute("SELECT pg_get_expr(d.adbin, d.adrelid) as default
                                  FROM pg_attribute a
                                  LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                                  WHERE a.attname='id' AND a.attrelid = 'pg_uuids'::regclass").first
    assert_nil col_desc['default']
  end

  def test_schema_dumper_for_uuid_primary_key_with_default_override_via_nil
    schema = dump_table_schema 'pg_uuids'
    assert_match(/\bcreate_table "pg_uuids", id: :uuid, default: nil/, schema)
  end

  def test_schema_dumper_for_uuid_primary_key_with_default_nil_in_legacy_migration
    @verbose_was = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    migration = Class.new(ActiveRecord::Migration[5.0]) do
      def version; 101 end
      def migrate(x)
        create_table('pg_uuids_4', id: :uuid, default: nil)
      end
    end.new
    ActiveRecord::Migrator.new(:up, [migration], ActiveRecord::Base.connection.schema_migration).migrate

    schema = dump_table_schema 'pg_uuids_4'
    assert_match(/\bcreate_table "pg_uuids_4", id: :uuid, default: nil/, schema)
  ensure
    drop_table 'pg_uuids_4'
    ActiveRecord::Migration.verbose = @verbose_was
    ActiveRecord::Base.connection.schema_migration.delete_all
  end
  uses_transaction :test_schema_dumper_for_uuid_primary_key_with_default_nil_in_legacy_migration
end

class PostgresqlUUIDTestInverseOf < ActiveRecord::PostgreSQLTestCase
  include PostgresqlUUIDHelper

  class UuidPost < ActiveRecord::Base
    self.table_name = 'pg_uuid_posts'
    has_many :uuid_comments, inverse_of: :uuid_post
  end

  class UuidComment < ActiveRecord::Base
    self.table_name = 'pg_uuid_comments'
    belongs_to :uuid_post
  end

  setup do
    connection.transaction do
      connection.create_table('pg_uuid_posts', id: :uuid, **uuid_default) do |t|
        t.string 'title'
      end
      connection.create_table('pg_uuid_comments', id: :uuid, **uuid_default) do |t|
        t.references :uuid_post, type: :uuid
        t.string 'content'
      end
    end
  end

  teardown do
    drop_table 'pg_uuid_comments'
    drop_table 'pg_uuid_posts'
  end

  def test_collection_association_with_uuid
    post    = UuidPost.create!
    comment = post.uuid_comments.create!
    assert post.uuid_comments.find(comment.id)
  end

  def test_find_with_uuid
    UuidPost.create!
    assert_raise ActiveRecord::RecordNotFound do
      UuidPost.find(123456)
    end
  end

  def test_find_by_with_uuid
    UuidPost.create!
    assert_nil UuidPost.find_by(id: 789)
  end
end
