# frozen_string_literal: true

require "cases/binary_test"

# Run the binary tests with PostgreSQL bytea decoder enabled
class BinaryWithDecoderTest < BinaryTest
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
