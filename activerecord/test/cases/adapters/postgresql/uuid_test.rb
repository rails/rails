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
      @connection.create_table('pg_uuids', id: :uuid) do |t|
        t.string 'name'
        t.uuid 'other_uuid', default: 'uuid_generate_v4()'
      end
    end
  end

  def teardown
    @connection.execute 'drop table if exists pg_uuids'
  end

  def test_auto_create_uuid
    u = UUID.create
    u.reload
    assert_not_nil u.other_uuid
  end
end
