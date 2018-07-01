# frozen_string_literal: true

require "cases/helper"

class PostgresqlTransactionTest < ActiveRecord::PostgreSQLTestCase
  self.use_transactional_tests = false

  class Sample < ActiveRecord::Base
    self.table_name = "samples"
  end

  setup do
    connection = ActiveRecord::Base.connection
    connection.drop_table "samples", if_exists: true
    connection.create_table("samples") do |t|
      t.integer "value"
    end
    Sample.establish_connection :arunit
  end

  teardown do
    ActiveRecord::Base.connection.drop_table "samples", if_exists: true
  end

  test "setting incorrect isolation raises an error and closes transaction" do
    assert_no_idle_transactions do
      assert_raises(KeyError) do
        Sample.transaction(isolation: "foobar") {}
      end
    end
  end

  private

    def assert_no_idle_transactions
      before = idle_transaction_count
      yield
      after = idle_transaction_count
      assert_equal before, after
    end

    def idle_transaction_count
      ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM pg_stat_activity WHERE state='idle in transaction' AND xact_start IS NOT NULL"
      ).values
    end
end
