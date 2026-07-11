# frozen_string_literal: true

require "cases/helper"
require "active_support/testing/ractors_assertions"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionTest < ActiveRecord::TestCase
      include ActiveSupport::Testing::RactorsAssertions
      self.use_transactional_tests = false

      teardown { reset_ractor_pool_state }

      if !in_memory_db? && RUBY_VERSION >= "4.0"
        def test_pool_initializes_from_spec
          config = db_config
          pool = RactorConnectionPool.new(pool_spec(config: config))
          assert_equal config, pool.db_config
          assert_equal :writing, pool.role
          assert_equal :default, pool.shard
          assert_equal ["ActiveRecord::Base", :writing, :default], pool.key
          assert pool.frozen?
        end

        def test_lease_connection_checks_out_once_and_marks_sticky
          pool = RactorConnectionPool.new(pool_spec)

          assert_not pool.active_connection?
          assert pool.permanent_lease?

          conn = pool.lease_connection
          assert_kind_of RactorConnectionProxy, conn
          assert pool.active_connection?
          assert_not pool.permanent_lease?

          # A second lease reuses the cached connection (no new checkout).
          assert_same conn, pool.lease_connection
        end

        def test_release_connection_returns_connection_and_clears_lease
          pool = RactorConnectionPool.new(pool_spec)
          pool.lease_connection

          assert pool.release_connection
          assert_not pool.active_connection?
          assert pool.permanent_lease?

          # Releasing with nothing leased is a no-op that returns false.
          assert_not pool.release_connection
        end

        def test_with_connection_yields_and_releases_when_not_sticky
          pool = RactorConnectionPool.new(pool_spec)

          yielded = nil
          pool.with_connection { |c| yielded = c }

          assert_kind_of RactorConnectionProxy, yielded
          assert_not pool.active_connection?
        end

        def test_with_connection_keeps_lease_when_already_sticky
          pool = RactorConnectionPool.new(pool_spec)
          conn = pool.lease_connection

          pool.with_connection { |c| assert_same conn, c }

          assert pool.active_connection?
        end

        def test_with_connection_prevent_permanent_checkout_releases_after
          pool = RactorConnectionPool.new(pool_spec)

          pool.with_connection(prevent_permanent_checkout: true) { |c| assert_kind_of RactorConnectionProxy, c }

          assert_not pool.active_connection?
        end

        def test_query_cache_starts_disabled
          pool = RactorConnectionPool.new(pool_spec)
          assert_not pool.query_cache_enabled
          assert pool.dirties_query_cache
        end

        def test_enable_and_disable_query_cache_bang
          pool = RactorConnectionPool.new(pool_spec)
          pool.enable_query_cache!
          assert pool.query_cache_enabled
          assert pool.dirties_query_cache

          pool.disable_query_cache!
          assert_not pool.query_cache_enabled
          assert pool.dirties_query_cache
        end

        def test_disable_query_cache_block_restores_previous_state
          pool = RactorConnectionPool.new(pool_spec)
          pool.enable_query_cache!
          assert pool.query_cache_enabled

          inside = nil
          pool.disable_query_cache { inside = pool.query_cache_enabled }

          assert_not inside
          assert pool.query_cache_enabled
        end

        def test_enable_query_cache_block_restores_previous_state
          pool = RactorConnectionPool.new(pool_spec)
          assert_not pool.query_cache_enabled

          inside = nil
          pool.enable_query_cache { inside = pool.query_cache_enabled }

          assert inside
          assert_not pool.query_cache_enabled
        end

        def test_with_pool_transaction_isolation_level_noop_when_default_is_nil
          previous = ActiveRecord.default_transaction_isolation_level
          ActiveRecord.default_transaction_isolation_level = nil

          yielded = false
          RactorConnectionPool.new(pool_spec).with_pool_transaction_isolation_level(:serializable, false) do
            yielded = true
          end
          assert yielded
        ensure
          ActiveRecord.default_transaction_isolation_level = previous
        end

        def test_with_pool_transaction_isolation_level_sets_and_restores
          previous = ActiveRecord.default_transaction_isolation_level
          pool = RactorConnectionPool.new(pool_spec)
          ActiveRecord.default_transaction_isolation_level = :read_committed

          observed = nil
          pool.with_pool_transaction_isolation_level(:serializable, false) do
            observed = pool.pool_transaction_isolation_level
          end

          assert_equal :serializable, observed
          assert_nil pool.pool_transaction_isolation_level
        ensure
          ActiveRecord.default_transaction_isolation_level = previous
        end

        def test_with_pool_transaction_isolation_level_raises_when_transaction_open_and_level_differs
          previous = ActiveRecord.default_transaction_isolation_level
          pool = RactorConnectionPool.new(pool_spec)
          ActiveRecord.default_transaction_isolation_level = :read_committed
          pool.pool_transaction_isolation_level = :serializable

          assert_raises(ActiveRecord::TransactionIsolationError) do
            pool.with_pool_transaction_isolation_level(:read_committed, true) { }
          end
        ensure
          ActiveRecord.default_transaction_isolation_level = previous
        end

        def test_handler_connection_pool_list_returns_ractor_pools
          pools = RactorConnectionHandler.instance.connection_pool_list
          assert pools.all? { |p| p.is_a?(RactorConnectionPool) }
          assert_includes pools.map { |p| p.db_config.name }, "primary"
        end

        def test_handler_each_connection_pool_yields_pools
          yielded = []
          RactorConnectionHandler.instance.each_connection_pool { |p| yielded << p }
          assert_equal RactorConnectionHandler.instance.connection_pool_list.map(&:key), yielded.map(&:key)
        end

        def test_handler_retrieve_connection_pool_for_base
          pool = RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal "primary", pool.db_config.name
          assert_equal ["ActiveRecord::Base", :writing, :default], pool.key
        end

        def test_handler_retrieve_connection_pool_returns_nil_for_unknown
          assert_nil RactorConnectionHandler.instance.retrieve_connection_pool("Nonexistent::Base")
        end

        def test_handler_connected_true_for_established
          assert RactorConnectionHandler.instance.connected?("ActiveRecord::Base")
        end

        def test_handler_connected_false_for_unknown
          assert_not RactorConnectionHandler.instance.connected?("Nonexistent::Base")
        end

        def test_handler_retrieve_connection_returns_proxy
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_kind_of RactorConnectionProxy, conn
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_handler_active_connections_after_checkout
          handler = RactorConnectionHandler.instance
          handler.retrieve_connection("ActiveRecord::Base")
          assert handler.active_connections?
        ensure
          handler.clear_active_connections!
        end

        def test_handler_clear_active_connections_releases
          handler = RactorConnectionHandler.instance
          handler.retrieve_connection("ActiveRecord::Base")
          assert handler.active_connections?
          handler.clear_active_connections!
          assert_not handler.active_connections?
        end

        def test_proxy_adapter_name_delegates_to_main
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_equal ActiveRecord::Base.lease_connection.adapter_name, conn.adapter_name
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_proxy_connected_and_active
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert conn.connected?
          assert conn.active?
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_proxy_verify_returns_self
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_same conn, conn.verify!
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_proxy_disconnect_releases_connection
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert conn.connected?
          conn.disconnect!
          assert_not conn.connected?
        end

        def test_proxy_quote_delegates_to_main
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_equal "'hello'", conn.quote("hello")
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_proxy_transaction_methods_dispatch
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_nothing_raised do
            conn.begin_db_transaction
            conn.exec_rollback_db_transaction
          end
        ensure
          RactorConnectionHandler.instance.clear_active_connections!
        end

        def test_checkout_and_adapter_name_in_non_main_ractor
          expected_adapter_name = ActiveRecord::Base.lease_connection.adapter_name
          result = on_ractor do
            handler = ConnectionAdapters::RactorConnectionHandler.instance
            pool = handler.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            name = conn.adapter_name
            conn.disconnect!
            name
          end
          assert_equal expected_adapter_name, result
        end

        def test_quote_in_non_main_ractor
          result = on_ractor do
            handler = ConnectionAdapters::RactorConnectionHandler.instance
            pool = handler.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            quoted = conn.quote("hello")
            conn.disconnect!
            quoted
          end
          assert_equal "'hello'", result
        end

        def test_query_dispatch_in_non_main_ractor
          result = on_ractor do
            token = ConnectionAdapters::RactorConnectionProxy.checkout_main_connection(
              "ActiveRecord::Base", :writing, :default,
            )
            request = ConnectionAdapters::RactorConnectionProxy::QueryRequest.new(
              sql: "SELECT 1 AS one",
              binds: [],
              name: "test",
              prepare: false,
              batch: false,
              allow_retry: false,
            )
            response = ConnectionAdapters::RactorConnectionProxy.dispatch_query(token, request)
            rows = response.to_result.rows
            ConnectionAdapters::RactorConnectionProxy.checkin_main_connection(token)
            rows
          end
          assert_equal [[1]], result
        end

        def test_error_is_ractor_shareable
          error = RactorConnectionProxy.error(StandardError.new("boom"))
          assert_ractor_shareable(error)
          assert_equal "StandardError", error.error_class_name
          assert_equal "boom", error.message
        end

        def test_unwrap_outcome_reraises_error_message
          error = RactorConnectionProxy.error(ActiveRecordError.new("kaboom"))
          raised = assert_raises(RuntimeError) do
            RactorConnectionProxy.unwrap_outcome(error)
          end
          assert_equal "kaboom", raised.message
        end

        def test_transaction_methods_in_non_main_ractor
          result = on_ractor do
            handler = ConnectionAdapters::RactorConnectionHandler.instance
            pool = handler.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            conn.begin_db_transaction
            conn.exec_rollback_db_transaction
            conn.disconnect!
            :ok
          end
          assert_equal :ok, result
        end
      end

      private
        def reset_ractor_pool_state
          ActiveSupport::IsolatedExecutionState.delete(:active_record_ractor_query_caches)
          ActiveSupport::IsolatedExecutionState.delete(:active_record_ractor_connection_leases)
          ActiveSupport::IsolatedExecutionState.delete("activerecord_pool_transaction_isolation_level_primary")
          cleanup_main_connections
        end

        def cleanup_main_connections
          RactorConnectionProxy.checkin_all_connections
        end

        def db_config
          ActiveRecord::Base.connection_pool.db_config
        end

        def pool_spec(connection_name: "ActiveRecord::Base", role: :writing, shard: :default, config: db_config)
          {
            db_config: config,
            connection_name: connection_name.to_s.freeze,
            role: role,
            shard: shard,
          }
        end
    end
  end
end
