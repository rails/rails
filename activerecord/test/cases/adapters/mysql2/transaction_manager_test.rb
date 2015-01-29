require "cases/helper"

class TransactionManagerTest < ActiveRecord::TestCase
  fixtures :tags

  self.use_transactional_fixtures = false

  def setup
    @transaction_manager = ActiveRecord::Base.connection.transaction_manager
  end

  def test_mysql2_connection_adapter_transaction_manager_instance
    assert_kind_of(ActiveRecord::ConnectionAdapters::Mysql2TransactionManager, @transaction_manager)
  end

  def test_deadlock_errors_dont_cause_rollbacks_to_non_existent_savepoints
    error = assert_raise(ActiveRecord::StatementInvalid) do
      ActiveRecord::Base.connection.transaction(joinable: false) do
        ActiveRecord::Base.connection.transaction do
          trigger_deadlock!
        end
      end
    end

    msg = "expected deadlock error, got '#{error.original_exception.message}'"
    assert_equal(1213, error.original_exception.error_number, "error_number: #{msg}")
    assert_equal('40001', error.original_exception.sql_state, "sql_state: #{msg}")
  end

  def test_detecting_a_deadlock_error
    assert_equal(false, @transaction_manager.send(:deadlock_error?, RuntimeError.new("Error")))
    assert_equal(true, @transaction_manager.send(:deadlock_error?, (trigger_deadlock! rescue $!)))
  end

  private
    def trigger_deadlock!
      conn1, conn2 = ActiveRecord::Base.connection_pool.connection, nil
      Thread.new { conn2 = ActiveRecord::Base.connection_pool.connection }.join

      conn1.transaction do
        conn2.transaction do
          conn1.execute("select id, name from tags where id = 1 for update")
          conn2.execute("select id, name from tags where id = 2 for update")

          [
            Thread.new { conn1.execute("update tags set name = 'hello' where id <> 1") },
            Thread.new { conn2.execute("update tags set name = 'world' where id <> 2") }
          ].each(&:join)
        end
      end
    end
end
