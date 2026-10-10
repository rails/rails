# frozen_string_literal: true

require "cases/helper"

class SQLite3TransactionTest < ActiveRecord::SQLite3TestCase
  test "shared_cached? is true when cache-mode is enabled" do
    with_connection(flags: shared_cache_flags) do |conn|
      assert_predicate(conn, :shared_cache?)
    end
  end

  test "shared_cached? is false when cache-mode is disabled" do
    flags = ::SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE

    with_connection(flags: flags) do |conn|
      assert_not_predicate(conn, :shared_cache?)
    end
  end

  test "raises when trying to open a transaction in an isolation level other than `read_uncommitted`" do
    with_connection do |conn|
      assert_raises(ActiveRecord::TransactionIsolationError) do
        conn.transaction(requires_new: true, isolation: :something) do
          conn.transaction_manager.materialize_transactions
        end
      end
    end
  end

  test "raises when trying to open a read_uncommitted transaction but shared-cache mode is turned off" do
    with_connection do |conn|
      error = assert_raises(StandardError) do
        conn.transaction(requires_new: true, isolation: :read_uncommitted) do
          conn.transaction_manager.materialize_transactions
        end
      end

      assert_match("You need to enable the shared-cache mode", error.message)
    end
  end

  test "opens a `read_uncommitted` transaction" do
    with_connection(flags: shared_cache_flags) do |conn1|
      conn1.create_table(:zines) { |t| t.column(:title, :string) } if in_memory_db?
      conn1.transaction do
        conn1.transaction_manager.materialize_transactions
        conn1.execute("INSERT INTO zines (title) VALUES ('foo')")

        with_connection(flags: shared_cache_flags) do |conn2|
          conn2.transaction(joinable: false, isolation: :read_uncommitted) do
            assert_not_empty(conn2.execute("SELECT * FROM zines WHERE title = 'foo'"))
          end
        end

        raise ActiveRecord::Rollback
      end
    end
  end

  test "reset the read_uncommitted PRAGMA when a transaction is rolled back" do
    with_connection(flags: shared_cache_flags) do |conn|
      conn.connect!
      conn.transaction(joinable: false, isolation: :read_uncommitted) do
        assert_not(read_uncommitted?(conn))
        conn.transaction_manager.materialize_transactions
        assert(read_uncommitted?(conn))

        raise ActiveRecord::Rollback
      end

      assert_not(read_uncommitted?(conn))
    end
  end

  test "reset the read_uncommitted PRAGMA when a transaction is committed" do
    with_connection(flags: shared_cache_flags) do |conn|
      conn.connect!
      conn.transaction(joinable: false, isolation: :read_uncommitted) do
        assert_not(read_uncommitted?(conn))
        conn.transaction_manager.materialize_transactions
        assert(read_uncommitted?(conn))
      end

      assert_not(read_uncommitted?(conn))
    end
  end

  test "set the read_uncommitted PRAGMA to its previous value" do
    with_connection(flags: shared_cache_flags) do |conn|
      conn.connect!
      conn.transaction(joinable: false, isolation: :read_uncommitted) do
        conn.instance_variable_get(:@raw_connection).read_uncommitted = true
        assert(read_uncommitted?(conn))
        conn.transaction_manager.materialize_transactions
        assert(read_uncommitted?(conn))
      end

      assert(read_uncommitted?(conn))
    end
  end

  private
    def read_uncommitted?(conn)
      conn.instance_variable_get(:@raw_connection).get_first_value("PRAGMA read_uncommitted") != 0
    end

    def shared_cache_flags
      ::SQLite3::Constants::Open::READWRITE | SQLite3::Constants::Open::CREATE | ::SQLite3::Constants::Open::SHAREDCACHE
    end

    def with_connection(options = {})
      options = options.dup
      if in_memory_db?
        options[:database] ||= "file::memory:"
        options[:flags] = options[:flags].to_i | ::SQLite3::Constants::Open::URI | ::SQLite3::Constants::Open::READWRITE
      else
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        options[:database] ||= db_config.database
      end
      conn = ActiveRecord::ConnectionAdapters::SQLite3Adapter.new(options)

      yield(conn)
    ensure
      conn.disconnect! if conn
    end
end

class SQLite3AutoRollbackTest < ActiveRecord::SQLite3TestCase
  self.use_transactional_tests = false

  class MemoryRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  class FullItem < MemoryRecord
    self.table_name = "full_items"
    attr_accessor :rolled_back
    after_rollback { self.rolled_back = true }
  end

  setup do
    MemoryRecord.establish_connection(adapter: "sqlite3", database: ":memory:")
    @conn = FullItem.lease_connection
    @conn.create_table(:full_items) { |t| t.text :body }
    @conn.execute("PRAGMA max_page_count = #{@conn.select_value("PRAGMA page_count") + 2}")
  end

  teardown do
    MemoryRecord.remove_connection
  end

  test "a transaction SQLite rolled back on its own raises the original error and rolls back records" do
    record = nil
    error = nil
    assert_no_queries_match(/ROLLBACK/) do
      error = assert_raises(ActiveRecord::StatementInvalid) do
        FullItem.transaction do
          record = FullItem.create!(body: "x")
          50.times { FullItem.create!(body: "y" * 20_000) }
        end
      end
    end

    assert_instance_of ::SQLite3::FullException, error.cause
    assert_not_predicate @conn, :transaction_open?
    assert_not_predicate record, :persisted?
    assert record.rolled_back
    assert_equal 0, FullItem.count
  end

  test "a nested transaction SQLite rolled back on its own raises the original error and rolls back records" do
    outer = inner = nil
    error = nil
    assert_no_queries_match(/ROLLBACK/) do
      error = assert_raises(ActiveRecord::StatementInvalid) do
        FullItem.transaction do
          outer = FullItem.create!(body: "x")
          FullItem.transaction(requires_new: true) do
            inner = FullItem.create!(body: "x")
            50.times { FullItem.create!(body: "y" * 20_000) }
          end
        end
      end
    end

    assert_instance_of ::SQLite3::FullException, error.cause
    assert_not_predicate @conn, :transaction_open?
    assert_not_predicate outer, :persisted?
    assert_not_predicate inner, :persisted?
    assert outer.rolled_back
    assert inner.rolled_back
    assert_equal 0, FullItem.count
  end
end
