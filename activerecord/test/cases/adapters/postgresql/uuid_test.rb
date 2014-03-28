# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

module PostgresqlUUIDHelper
  def connection
    @connection ||= ActiveRecord::Base.connection
  end

  def enable_uuid_ossp
    unless connection.extension_enabled?('uuid-ossp')
      connection.enable_extension 'uuid-ossp'
      connection.commit_db_transaction
    end

    connection.reconnect!
  end

  def drop_table(name)
    connection.execute "drop table if exists #{name}"
  end
end

class PostgresqlUUIDTest < ActiveRecord::TestCase
  include PostgresqlUUIDHelper

  class UUIDType < ActiveRecord::Base
    self.table_name = "uuid_data_type"
  end

  setup do
    connection.create_table "uuid_data_type" do |t|
      t.uuid 'guid'
    end
  end

  teardown do
    drop_table "uuid_data_type"
  end

  def test_data_type_of_uuid_types
    column = UUIDType.columns_hash["guid"]
    assert_equal :uuid, column.type
    assert_equal "uuid", column.sql_type
    assert_not column.number?
    assert_not column.text?
    assert_not column.binary?
    assert_not column.array
  end

  def test_uuid_formats
    ["A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11",
     "{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}",
     "a0eebc999c0b4ef8bb6d6bb9bd380a11",
     "a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11",
     "{a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}"].each do |valid_uuid|
      UUIDType.create(guid: valid_uuid)
      uuid = UUIDType.last
      assert_equal "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", uuid.guid
    end
  end
end

class PostgresqlUUIDGenerationTest < ActiveRecord::TestCase
  include PostgresqlUUIDHelper

  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  setup do
    enable_uuid_ossp

    connection.create_table('pg_uuids', id: :uuid, default: 'uuid_generate_v1()') do |t|
      t.string 'name'
      t.uuid 'other_uuid', default: 'uuid_generate_v4()'
    end
  end

  teardown do
    drop_table "pg_uuids"
  end

  if ActiveRecord::Base.connection.supports_extensions?
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
      assert_equal nil, seq
    end

    def test_schema_dumper_for_uuid_primary_key
      schema = StringIO.new
      ActiveRecord::SchemaDumper.dump(connection, schema)
      assert_match(/\bcreate_table "pg_uuids", id: :uuid, default: "uuid_generate_v1\(\)"/, schema.string)
      assert_match(/t\.uuid   "other_uuid", default: "uuid_generate_v4\(\)"/, schema.string)
    end
  end
end

class PostgresqlUUIDTestNilDefault < ActiveRecord::TestCase
  include PostgresqlUUIDHelper

  setup do
    enable_uuid_ossp

    connection.create_table('pg_uuids', id: false) do |t|
      t.primary_key :id, :uuid, default: nil
      t.string 'name'
    end
  end

  teardown do
    drop_table "pg_uuids"
  end

  if ActiveRecord::Base.connection.supports_extensions?
    def test_id_allows_default_override_via_nil
      col_desc = connection.execute("SELECT pg_get_expr(d.adbin, d.adrelid) as default
                                    FROM pg_attribute a
                                    LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                                    WHERE a.attname='id' AND a.attrelid = 'pg_uuids'::regclass").first
      assert_nil col_desc["default"]
    end
  end
end

class PostgresqlUUIDTestInverseOf < ActiveRecord::TestCase
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
    enable_uuid_ossp

    connection.transaction do
      connection.create_table('pg_uuid_posts', id: :uuid) do |t|
        t.string 'title'
      end
      connection.create_table('pg_uuid_comments', id: :uuid) do |t|
        t.uuid :uuid_post_id, default: 'uuid_generate_v4()'
        t.string 'content'
      end
    end
  end

  teardown do
    connection.transaction do
      drop_table "pg_uuid_comments"
      drop_table "pg_uuid_posts"
    end
  end

  if ActiveRecord::Base.connection.supports_extensions?
    def test_collection_association_with_uuid
      post    = UuidPost.create!
      comment = post.uuid_comments.create!
      assert post.uuid_comments.find(comment.id)
    end
  end
end
