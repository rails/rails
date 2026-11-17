# frozen_string_literal: true

require "cases/adapters/postgresql/money_test"

class PostgresqlMoneyWithDecoderTest < PostgresqlMoneyTest
  def setup
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_money = true
    ActiveRecord::Base.connection_pool.disconnect!
    super
  end

  def teardown
    super
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_money = false
    ActiveRecord::Base.connection_pool.disconnect!
  end
end
