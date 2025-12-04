# frozen_string_literal: true

require "cases/adapters/postgresql/bytea_test"

class PostgresqlByteaWithDecoderTest < PostgresqlByteaTest
  def setup
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_bytea = true
    ActiveRecord::Base.connection_pool.disconnect!
    super
  end

  def teardown
    super
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_bytea = false
    ActiveRecord::Base.connection_pool.disconnect!
  end
end
