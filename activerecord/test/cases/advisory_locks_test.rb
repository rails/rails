# frozen_string_literal: true

require "cases/helper"

class AdvisoryLocksTest < ActiveRecord::TestCase
  def setup
    skip("Adapter does not support advisory locks") unless connection.supports_advisory_locks?
  end

  def test_get_advisory_lock_raises_without_reconnecting_after_session_loss
    with_duplicate_connection do |lock_connection|
      lock_a = nested_lock_arg(0)
      lock_b = nested_lock_arg(1)
      assert lock_connection.get_advisory_lock(lock_a)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        lock_connection.get_advisory_lock(lock_b)
      end
      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_a), "the killed session must release lock_a"
        assert other.release_advisory_lock(lock_a)
        assert other.get_advisory_lock(lock_b), "lock_b must not be acquired on a new session"
        assert other.release_advisory_lock(lock_b)
      end
    end
  end

  def test_release_advisory_lock_raises_without_reconnecting_after_session_loss
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished) do
        lock_connection.release_advisory_lock(lock_arg)
      end
      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "the killed session must release the lock"
        assert other.release_advisory_lock(lock_arg)
      end
    end
  end

  def test_query_raises_without_reconnecting_while_advisory_lock_is_held
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
        lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      end
      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "the killed session must release the lock"
        assert other.release_advisory_lock(lock_arg)
      end
    end
  end

  def test_verify_raises_without_reconnecting_while_advisory_lock_is_held
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      kill_session_by_other_connection(lock_connection)

      error = assert_raises(ActiveRecord::ConnectionNotEstablished) do
        lock_connection.verify!
      end
      assert_match(/held advisory locks cannot be restored/, error.message)
      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "the killed session must release the lock"
        assert other.release_advisory_lock(lock_arg)
      end
    end
  end

  def test_query_can_reconnect_after_last_advisory_lock_is_released
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)
      assert lock_connection.release_advisory_lock(lock_arg)
      original_session_id = session_id_of(lock_connection)

      kill_session_by_other_connection(lock_connection)

      assert_equal 1, lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      assert_not_equal original_session_id, session_id_of(lock_connection)
    end
  end

  def test_get_advisory_lock_reconnects_before_acquiring_when_no_lock_is_held
    with_duplicate_connection do |lock_connection|
      original_session_id = session_id_of(lock_connection)

      kill_session_by_other_connection(lock_connection)

      assert lock_connection.get_advisory_lock(lock_arg)
      assert_not_equal original_session_id, session_id_of(lock_connection)
      assert lock_connection.release_advisory_lock(lock_arg)
    end
  end

  def test_releasing_one_of_multiple_advisory_locks_keeps_reconnect_disabled
    with_duplicate_connection do |lock_connection|
      lock_a = nested_lock_arg(0)
      lock_b = nested_lock_arg(1)
      assert lock_connection.get_advisory_lock(lock_a)
      assert lock_connection.get_advisory_lock(lock_b)
      assert lock_connection.release_advisory_lock(lock_b)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
        lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      end
      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_a), "the killed session must release lock_a"
        assert other.release_advisory_lock(lock_a)
      end
    end
  end

  def test_releasing_one_recursive_acquisition_keeps_reconnect_disabled
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)
      assert lock_connection.get_advisory_lock(lock_arg)
      assert lock_connection.release_advisory_lock(lock_arg)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
        lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      end
      assert_not lock_connection.active?
    end
  end

  def test_releasing_an_untracked_lock_does_not_clear_a_tracked_lock
    with_duplicate_connection do |lock_connection|
      tracked_lock = nested_lock_arg(0)
      untracked_lock = nested_lock_arg(1)
      assert lock_connection.get_advisory_lock(tracked_lock)
      assert acquire_advisory_lock_without_tracking(lock_connection, untracked_lock)
      assert lock_connection.release_advisory_lock(untracked_lock)

      kill_session_by_other_connection(lock_connection)

      assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
        lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      end
      assert_not lock_connection.active?
    end
  end

  def test_explicit_reconnect_clears_advisory_lock_tracking
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      lock_connection.reconnect!

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "reconnecting must release the old session's lock"
        assert other.release_advisory_lock(lock_arg)
      end

      assert_query_reconnects_after_session_loss(lock_connection)
    end
  end

  def test_disconnect_clears_advisory_lock_tracking
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      lock_connection.disconnect!

      assert_equal 1, lock_connection.query_value("SELECT 1", nil, allow_retry: true)
    end
  end

  def test_reset_clears_advisory_lock_tracking
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      lock_connection.reset!

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "resetting must release the session's lock"
        assert other.release_advisory_lock(lock_arg)
      end

      assert_query_reconnects_after_session_loss(lock_connection)
    end
  end

  def test_connection_recovers_on_next_lease_after_lock_session_loss
    pool = build_duplicate_pool
    lock_connection = pool.checkout
    original_session_id = session_id_of(lock_connection)
    assert lock_connection.get_advisory_lock(lock_arg)

    kill_session_by_other_connection(lock_connection)

    assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
      lock_connection.query_value("SELECT 1", nil, allow_retry: true)
    end

    lock_connection.close
    recovered_connection = pool.checkout

    assert_same lock_connection, recovered_connection
    assert_equal 1, recovered_connection.query_value("SELECT 1", nil, allow_retry: true)
    assert_not_equal original_session_id, session_id_of(recovered_connection)
  ensure
    recovered_connection&.close if recovered_connection&.in_use?
    lock_connection&.close if lock_connection&.in_use?
    pool&.disconnect!
  end

  def test_release_advisory_lock_raises_when_connection_needs_reconnect
    with_duplicate_connection do |lock_connection|
      lock_connection.instance_variable_set(:@needs_reconnect, true)

      error = assert_raises(ActiveRecord::ConnectionNotEstablished) do
        lock_connection.release_advisory_lock(lock_arg)
      end
      assert_equal "The connection is not active", error.message
      assert_predicate lock_connection, :needs_reconnect?
    ensure
      lock_connection.instance_variable_set(:@needs_reconnect, false)
    end
  end

  def test_advisory_lock_methods_do_not_retry_the_lock_query
    with_duplicate_connection do |lock_connection|
      spy_on_method(lock_connection, :query_value) do |calls|
        assert lock_connection.get_advisory_lock(lock_arg)
        assert lock_connection.release_advisory_lock(lock_arg)

        assert_equal 2, calls.size
        calls.each do |call|
          assert_equal false, call[:kwargs][:allow_retry]
        end
      end
    end
  end

  def test_get_advisory_lock_connects_when_not_connected
    with_duplicate_connection do |lock_connection|
      lock_connection.disconnect!

      assert lock_connection.get_advisory_lock(lock_arg)
      assert lock_connection.release_advisory_lock(lock_arg)
    end
  end

  def test_release_advisory_lock_connects_when_not_connected
    with_duplicate_connection do |lock_connection|
      lock_connection.disconnect!

      assert_not lock_connection.release_advisory_lock(lock_arg)
      assert_predicate lock_connection, :active?
    end
  end

  def test_get_advisory_lock_returns_false_when_held_by_other_session
    with_duplicate_connection do |holder|
      with_duplicate_connection do |contender|
        assert holder.get_advisory_lock(lock_arg)
        assert_not contender.get_advisory_lock(lock_arg)
        assert holder.release_advisory_lock(lock_arg)
      end
    end
  end

  def test_release_advisory_lock_returns_false_when_not_held
    with_duplicate_connection do |lock_connection|
      assert_not lock_connection.release_advisory_lock(lock_arg)
    end
  end

  def test_get_advisory_lock_connects_before_dirtying_a_lazy_transaction
    with_duplicate_connection do |lock_connection|
      lock_connection.disconnect!

      lock_connection.transaction do
        assert_not lock_connection.current_transaction.materialized?
        assert lock_connection.get_advisory_lock(lock_arg)
        assert_predicate lock_connection.current_transaction, :materialized?
        assert lock_connection.release_advisory_lock(lock_arg)
      end
    end
  end

  def test_release_advisory_lock_connects_before_dirtying_a_lazy_transaction
    with_duplicate_connection do |lock_connection|
      lock_connection.disconnect!

      lock_connection.transaction do
        assert_not lock_connection.current_transaction.materialized?
        assert_not lock_connection.release_advisory_lock(lock_arg)
        assert_predicate lock_connection.current_transaction, :materialized?
      end
    end
  end

  def test_get_advisory_lock_does_not_reconnect_while_materializing_lazy_transaction
    with_duplicate_connection do |lock_connection|
      lock_a = nested_lock_arg(0)
      lock_b = nested_lock_arg(1)
      assert lock_connection.get_advisory_lock(lock_a)

      with_session_killed_after_active_probe(lock_connection) do
        assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
          lock_connection.transaction do
            assert_not lock_connection.current_transaction.materialized?
            lock_connection.get_advisory_lock(lock_b)
          end
        end
      end

      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_a), "the killed session must release lock_a"
        assert other.release_advisory_lock(lock_a)
        assert other.get_advisory_lock(lock_b), "lock_b must not be acquired on a new session"
        assert other.release_advisory_lock(lock_b)
      end
    end
  end

  def test_release_advisory_lock_does_not_reconnect_while_materializing_lazy_transaction
    with_duplicate_connection do |lock_connection|
      assert lock_connection.get_advisory_lock(lock_arg)

      with_session_killed_after_active_probe(lock_connection) do
        assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
          lock_connection.transaction do
            assert_not lock_connection.current_transaction.materialized?
            lock_connection.release_advisory_lock(lock_arg)
          end
        end
      end

      assert_not lock_connection.active?

      with_duplicate_connection do |other|
        assert other.get_advisory_lock(lock_arg), "the killed session must release the lock"
        assert other.release_advisory_lock(lock_arg)
      end
    end
  end

  private
    def connection
      ActiveRecord::Base.lease_connection
    end

    def with_duplicate_connection
      pool = build_duplicate_pool
      duplicate = pool.checkout
      yield duplicate
    ensure
      duplicate&.close
      pool&.disconnect!
    end

    def with_session_killed_after_active_probe(lock_connection, &block)
      original_active = lock_connection.method(:active?)
      killed = false
      active_then_kill = lambda do
        active = original_active.call
        if active && !killed
          killed = true
          kill_session_by_other_connection(lock_connection)
        end
        active
      end

      lock_connection.stub(:active?, active_then_kill, &block)
      assert killed, "the session must be killed after the active? probe"
    end

    def assert_query_reconnects_after_session_loss(lock_connection)
      original_session_id = session_id_of(lock_connection)
      kill_session_by_other_connection(lock_connection)

      assert_equal 1, lock_connection.query_value("SELECT 1", nil, allow_retry: true)
      assert_not_equal original_session_id, session_id_of(lock_connection)
    end

    def acquire_advisory_lock_without_tracking(lock_connection, lock)
      case lock_connection.adapter_name
      when "Mysql2", "Trilogy"
        lock_connection.query_value("SELECT GET_LOCK(#{lock_connection.quote(lock.to_s)}, 0)") == 1
      when "PostgreSQL"
        lock_connection.query_value("SELECT pg_try_advisory_lock(#{lock})")
      else
        raise "Unsupported adapter: #{lock_connection.adapter_name}"
      end
    end

    def kill_session_by_other_connection(lock_connection)
      session_id = session_id_of(lock_connection)

      with_duplicate_connection do |killer|
        case lock_connection.adapter_name
        when "Mysql2", "Trilogy"
          killer.execute("KILL #{session_id}")
        when "PostgreSQL"
          killer.execute("SELECT pg_terminate_backend(#{session_id})")
        end
      end
    end

    def session_id_of(lock_connection)
      case lock_connection.adapter_name
      when "Mysql2", "Trilogy"
        lock_connection.query_value("SELECT CONNECTION_ID()")
      when "PostgreSQL"
        lock_connection.query_value("SELECT pg_backend_pid()")
      else
        raise "Unsupported adapter: #{lock_connection.adapter_name}"
      end
    end

    def build_duplicate_pool
      config = ActiveRecord::Base.connection_pool.db_config
      db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
        config.env_name,
        config.name,
        config.configuration_hash
      )
      pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(
        ActiveRecord::Base, db_config, :writing, :default
      )
      ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_config)
    end

    def spy_on_method(object, method_name)
      calls = []
      original = object.method(method_name)
      object.define_singleton_method(method_name) do |*args, **kwargs, &block|
        calls << { args: args, kwargs: kwargs }
        original.call(*args, **kwargs, &block)
      end
      yield calls
    ensure
      object.singleton_class.send(:remove_method, method_name)
    end

    def lock_arg
      current_adapter?(:PostgreSQLAdapter) ? LOCK_ID : LOCK_NAME
    end

    def nested_lock_arg(index)
      lock_arg.is_a?(Integer) ? LOCK_ID + index : "#{LOCK_NAME}_#{index}"
    end

    LOCK_ID = 1234_5678
    LOCK_NAME = "advisory_locks_test"
end
