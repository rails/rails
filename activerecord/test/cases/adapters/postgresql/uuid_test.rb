# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlUUIDTest < ActiveRecord::TestCase
  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    unless @connection.supports_extensions?
      return skip "do not test on PG without uuid-ossp"
    end

    unless @connection.extension_enabled?('uuid-ossp')
      @connection.enable_extension 'uuid-ossp'
      @connection.commit_db_transaction
    end

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuids', id: :uuid, default: 'uuid_generate_v1()') do |t|
        t.string 'name'
        t.uuid 'other_uuid', default: 'uuid_generate_v4()'
      end
    end
  end

  def teardown
    @connection.execute 'drop table if exists pg_uuids'
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
    pk, seq = @connection.pk_and_sequence_for('pg_uuids')
    assert_equal 'id', pk
    assert_equal nil, seq
  end

  def test_schema_dumper_for_uuid_primary_key
    schema = StringIO.new
    ActiveRecord::SchemaDumper.dump(@connection, schema)
    assert_match(/\bcreate_table "pg_uuids", id: :uuid, default: "uuid_generate_v1\(\)"/, schema.string)
    assert_match(/t\.uuid   "other_uuid", default: "uuid_generate_v4\(\)"/, schema.string)
  end

  def test_change_column_default
    @connection.add_column :pg_uuids, :thingy, :uuid, null: false, default: "uuid_generate_v1()"
    UUID.reset_column_information
    column = UUID.columns.find { |c| c.name == 'thingy' }
    assert_equal "uuid_generate_v1()", column.default_function

    @connection.change_column :pg_uuids, :thingy, :uuid, null: false, default: "uuid_generate_v4()"

    UUID.reset_column_information
    column = UUID.columns.find { |c| c.name == 'thingy' }
    assert_equal "uuid_generate_v4()", column.default_function
  end
end

class PostgresqlUUIDTestNilDefault < ActiveRecord::TestCase
  class UUID < ActiveRecord::Base
    self.table_name = 'pg_uuids'
  end

  def setup
    @connection = ActiveRecord::Base.connection

    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuids', id: false) do |t|
        t.primary_key :id, :uuid, default: nil
        t.string 'name'
      end
    end
  end

  def teardown
    @connection.execute 'drop table if exists pg_uuids'
  end

  def test_id_allows_default_override_via_nil
    col_desc = @connection.execute("SELECT pg_get_expr(d.adbin, d.adrelid) as default
                                    FROM pg_attribute a
                                    LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                                    WHERE a.attname='id' AND a.attrelid = 'pg_uuids'::regclass").first
    assert_nil col_desc["default"]
  end
end

class PostgresqlUUIDTestInverseOf < ActiveRecord::TestCase
  class UuidPost < ActiveRecord::Base
    self.table_name = 'pg_uuid_posts'
    has_many :uuid_comments, inverse_of: :uuid_post
  end

  class UuidComment < ActiveRecord::Base
    self.table_name = 'pg_uuid_comments'
    belongs_to :uuid_post
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.reconnect!

    @connection.transaction do
      @connection.create_table('pg_uuid_posts', id: :uuid) do |t|
        t.string 'title'
      end
      @connection.create_table('pg_uuid_comments', id: :uuid) do |t|
        t.uuid :uuid_post_id, default: 'uuid_generate_v4()'
        t.string 'content'
      end
    end
  end

  def teardown
    @connection.transaction do
      @connection.execute 'drop table if exists pg_uuid_comments'
      @connection.execute 'drop table if exists pg_uuid_posts'
    end
  end

  def test_collection_association_with_uuid
    post    = UuidPost.create!
    comment = post.uuid_comments.create!
    assert post.uuid_comments.find(comment.id)
  end
end
