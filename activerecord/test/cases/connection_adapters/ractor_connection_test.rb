# frozen_string_literal: true

# :markup: markdown

require "cases/helper"
require "active_support/testing/ractors_assertions"
require "models/course"
require "models/topic"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionTest < ActiveRecord::TestCase
      include ActiveSupport::Testing::RactorsAssertions
      include ActiveSupport::Testing::Isolation
      self.use_transactional_tests = false

      # Never referenced on the main Ractor, so its memoized class state is
      # guaranteed cold when a worker touches it first.
      class ColdModel < ActiveRecord::Base
        self.table_name = "topics"
      end

      if !in_memory_db? && RUBY_VERSION >= "4.0"
        setup do
          create_widgets_table
          # What a Ractor-ready application arranges at boot: the railtie
          # makes `ActiveRecord.query_transformers` shareable after
          # initialization, and the Notifications subscription snapshot must
          # be shareable for worker Ractors to build their own notifier. The
          # test-environment subscribers (e.g. SQLCounter) close over
          # unshareable state, so workers get an empty snapshot here.
          Ractor.make_shareable(ActiveRecord.query_transformers)
          install_shareable_notifications_snapshot
        end

        teardown do
          RactorConnectionProxy.checkin_all_connections
          drop_widgets_table
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end

        # --- pool ---

        def test_pool_initializes_from_spec
          config = db_config
          spec = pool_spec(config: config)
          pool = RactorConnectionPool.new(spec)
          assert_equal config, pool.db_config
          assert_equal :writing, pool.role
          assert_equal :default, pool.shard
          assert_equal ["ActiveRecord::Base", :writing, :default, spec[:pool_token]], pool.key
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

          pool.disable_query_cache!
          assert_not pool.query_cache_enabled
        end

        def test_disable_query_cache_block_restores_previous_state
          pool = RactorConnectionPool.new(pool_spec)
          pool.enable_query_cache!

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

        # --- handler ---

        def test_handler_connection_pool_list_returns_ractor_pools
          pools = RactorConnectionHandler.instance.connection_pool_list
          assert pools.all? { |p| p.is_a?(RactorConnectionPool) }
          assert_includes pools.map { |p| p.db_config.name }, "primary"
        end

        def test_handler_retrieve_connection_pool_for_base
          pool = RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal "primary", pool.db_config.name
          assert_equal ["ActiveRecord::Base", :writing, :default, RactorConnectionProxy.pool_token(main_pool)], pool.key
        end

        def test_handler_retrieve_connection_pool_returns_nil_for_unknown
          assert_nil RactorConnectionHandler.instance.retrieve_connection_pool("Nonexistent::Base")
        end

        def test_handler_connected_false_for_unknown
          assert_not RactorConnectionHandler.instance.connected?("Nonexistent::Base")
        end

        def test_handler_retrieve_connection_returns_proxy
          conn = RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
          assert_kind_of RactorConnectionProxy, conn
        end

        def test_handler_clear_active_connections_releases
          handler = RactorConnectionHandler.instance
          handler.retrieve_connection("ActiveRecord::Base")
          assert handler.active_connections?
          assert handler.connected?("ActiveRecord::Base")
          handler.clear_active_connections!
          assert_not handler.active_connections?
        end

        # --- proxy: concrete adapter fidelity ---

        def test_proxy_reports_concrete_adapter_behavior
          real = ActiveRecord::Base.lease_connection
          conn = proxy_connection

          assert_equal real.adapter_name, conn.adapter_name
          assert_equal real.quote("it's"), conn.quote("it's")
          assert_equal real.quote_column_name("name"), conn.quote_column_name("name")
          assert_equal real.quote_table_name("a.b"), conn.quote_table_name("a.b")
          assert_equal real.supports_insert_returning?, conn.supports_insert_returning?
          assert_equal real.supports_savepoints?, conn.supports_savepoints?
          assert_equal real.high_precision_current_timestamp, conn.high_precision_current_timestamp
        end

        def test_proxy_health_methods_reflect_underlying_connection
          conn = proxy_connection

          assert conn.connected?
          assert conn.active?
          assert_same conn, conn.verify!

          conn.release_connection
          assert_not conn.connected?
          assert_not conn.active?
        end

        def test_token_pinned_connection_delegates_reconnect_decisions
          conn = proxy_connection
          main_side = RactorConnectionProxy.connections.values.first

          assert_not main_side.send(:reconnect_can_restore_state?)

          conn.release_connection
          assert main_side.send(:reconnect_can_restore_state?)
        end

        def test_stale_pinned_connection_does_not_reconnect_away_an_open_transaction
          conn = proxy_connection
          main_side = RactorConnectionProxy.connections.values.first
          main_side.define_singleton_method(:reconnect!) do |**|
            raise "the concrete adapter must not reconnect a token-pinned connection on its own"
          end

          conn.transaction do
            conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('first', 1)"))

            # Simulate a connection that looks dead mid-transaction: unverified,
            # no recent activity, failing liveness checks. The transaction state
            # lives in the worker-side proxy, so the concrete adapter's own
            # transaction manager is empty; without delegated reconnect
            # decisions, ensure_connection_ready would verify-reconnect here and
            # silently drop the open transaction.
            main_side.instance_variable_set(:@verified, false)
            main_side.instance_variable_set(:@last_activity, nil)
            main_side.define_singleton_method(:active?) { false }

            conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('second', 2)"))
          end

          names = conn.select_values("SELECT name FROM #{widgets_table} ORDER BY id")
          assert_equal ["first", "second"], names
        ensure
          if main_side
            singleton = main_side.singleton_class
            %i[reconnect! active?].each do |name|
              singleton.send(:remove_method, name) if singleton.method_defined?(name, false)
            end
          end
        end

        def test_execute_returns_materialized_result
          # Raw driver results cannot cross the Ractor boundary; this is the
          # documented transport behavior of the proxy's `execute`.
          result = proxy_connection.execute("SELECT 1 AS one")
          assert_kind_of ActiveRecord::Result, result
          assert_equal [[1]], result.rows
        end

        def test_select_all_preserves_concrete_column_types
          conn = proxy_connection
          conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('w', 5)"))

          sql = "SELECT id, name FROM #{widgets_table}"
          result = conn.select_all(sql)
          direct = ActiveRecord::Base.lease_connection.select_all(sql)

          assert_equal direct.column_types, result.column_types
          if (expected = direct.column_types["id"])
            assert_equal expected.type, result.column_types["id"].type
          end
        end

        def test_insert_returns_generated_id
          conn = proxy_connection
          first = conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('a', 1)"))
          second = conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('b', 2)"))

          assert_kind_of Integer, first
          assert_equal first + 1, second
        end

        # On MySQL adapters this shape is the natural one, covered by
        # test_insert_returns_generated_id; the emulation below is SQLite
        # specific.
        if current_adapter?(:SQLite3Adapter)
          def test_insert_returns_generated_id_when_adapter_reads_id_from_the_connection
            conn = proxy_connection
            main_side = RactorConnectionProxy.connections.values.first

            # Emulate a MySQL-shaped adapter: no INSERT ... RETURNING, the
            # generated id is read off the physical connection after the query.
            # The transport must carry that id back even though the insert
            # result itself has no rows.
            conn.define_singleton_method(:supports_insert_returning?) { false }
            main_side.define_singleton_method(:supports_insert_returning?) { false }
            main_side.define_singleton_method(:last_inserted_id) do |_result|
              @raw_connection.last_insert_row_id
            end

            id = conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('no_returning', 3)"))

            assert_kind_of Integer, id
            assert_equal id, conn.select_value("SELECT id FROM #{widgets_table} WHERE name = 'no_returning'")
          ensure
            if main_side
              singleton = main_side.singleton_class
              %i[supports_insert_returning? last_inserted_id].each do |name|
                singleton.send(:remove_method, name) if singleton.method_defined?(name, false) || singleton.private_method_defined?(name, false)
              end
            end
          end
        end

        def test_exec_query_casts_binds_with_concrete_adapter
          conn = proxy_connection
          skip unless conn.prepared_statements
          conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('cheap', 1)"))
          conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('dear', 10)"))

          rows = conn.exec_query(
            "SELECT name FROM #{widgets_table} WHERE price > #{bind_placeholder(1)}", "SQL",
            [Relation::QueryAttribute.new("price", 5, Type::Integer.new)]
          ).rows
          assert_equal [["dear"]], rows
        end

        def test_arel_compilation_uses_token_pinned_connection
          conn = proxy_connection
          table = Arel::Table.new(name: widgets_table)
          manager = table.project(table[:id]).lock(Arel.sql("FOR UPDATE"))

          sql = conn.to_sql(manager)

          if current_adapter?(:SQLite3Adapter)
            # SQLite's visitor drops FOR UPDATE; getting it here would mean the
            # SQL was compiled by another adapter's visitor.
            assert_no_match(/FOR UPDATE/, sql)
          else
            assert_match(/FOR UPDATE/, sql)
          end

          # Compilation must not check out a second main-pool connection.
          assert_equal 1, main_pool.connections.size
        end

        def test_transaction_commit_and_rollback_through_transaction_api
          conn = proxy_connection

          conn.transaction do
            conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('kept', 1)"))
          end
          conn.transaction do
            conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('gone', 2)"))
            raise ActiveRecord::Rollback
          end

          names = conn.select_values("SELECT name FROM #{widgets_table} ORDER BY name")
          assert_equal ["kept"], names
        end

        def test_nested_savepoint_rollback_preserves_outer_transaction
          conn = proxy_connection

          conn.transaction do
            conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('outer', 1)"))
            conn.transaction(requires_new: true) do
              conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('inner', 2)"))
              raise ActiveRecord::Rollback
            end
          end

          assert_equal ["outer"], conn.select_values("SELECT name FROM #{widgets_table}")
        end

        def test_database_errors_reconstruct_their_original_class
          error = assert_raises(ActiveRecord::StatementInvalid) do
            proxy_connection.select_value("SELECT * FROM nonexistent_ractor_table")
          end
          assert_match(/nonexistent_ractor_table/, error.message)
        end

        def test_transport_error_reconstruction
          response = RactorConnectionProxy::ErrorResponse.new(
            ActiveRecord::StatementInvalid.new("boom", sql: "SELECT 1")
          )
          assert_ractor_shareable(response)

          pool = RactorConnectionPool.new(pool_spec)
          raised = assert_raises(ActiveRecord::StatementInvalid) do
            RactorConnectionProxy.raise_transport_error(response, connection_pool: pool)
          end
          assert_equal "boom", raised.message
          assert_equal "SELECT 1", raised.sql
          assert_same pool, raised.connection_pool
        end

        def test_transport_error_falls_back_to_remote_error_preserving_class_name
          # MismatchedForeignKey cannot be rebuilt from (message, sql), so the
          # transport surfaces a RemoteError that names the original class.
          response = RactorConnectionProxy::ErrorResponse.new(
            ActiveRecord::MismatchedForeignKey.new(message: "fk mismatch")
          )

          raised = assert_raises(RactorConnectionProxy::RemoteError) do
            RactorConnectionProxy.raise_transport_error(response)
          end
          assert_equal "ActiveRecord::MismatchedForeignKey", raised.remote_class_name
          assert_match(/fk mismatch/, raised.message)
        end

        # --- proxy: lifecycle ---

        def test_close_returns_connection_to_pool_and_clears_lease
          pool = RactorConnectionPool.new(pool_spec)
          conn = pool.lease_connection

          conn.close

          assert_not pool.active_connection?
          assert_not conn.connected?
          assert_empty RactorConnectionProxy.connections

          # The pool hands out a fresh, working connection afterwards.
          assert_equal 1, pool.lease_connection.select_value("SELECT 1")
        end

        def test_throw_away_removes_connection_from_both_pools
          pool = RactorConnectionPool.new(pool_spec)
          conn = pool.checkout

          assert_nothing_raised { conn.throw_away! }

          assert_not conn.connected?
          assert_empty RactorConnectionProxy.connections
        end

        def test_checkin_all_connections_releases_stranded_tokens
          # The external lifecycle hook for worker Ractors that die without
          # releasing their token-pinned connections.
          on_ractor do
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            pool.lease_connection
            nil
          end

          assert_equal 1, RactorConnectionProxy.connections.size
          RactorConnectionProxy.checkin_all_connections
          assert_empty RactorConnectionProxy.connections
        end

        # --- ordinary entry points from a worker Ractor ---

        def test_select_value_through_automatic_handler_from_worker_ractor
          # `ActiveRecord::Base.connection_handler` resolves to the Ractor
          # handler automatically off the main Ractor; no explicit wiring.
          result = on_ractor do
            conn = ActiveRecord::Base.lease_connection
            value = conn.select_value("SELECT 41 + 1")
            ActiveRecord::Base.release_connection
            value
          end
          assert_equal 42, result
        end

        def test_transaction_from_worker_ractor
          table = widgets_table
          committed, rolled_back = on_ractor(table) do |widgets|
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            conn.transaction do
              conn.insert(Arel.sql("INSERT INTO #{widgets} (name, price) VALUES ('kept', 1)"))
            end
            conn.transaction do
              conn.insert(Arel.sql("INSERT INTO #{widgets} (name, price) VALUES ('gone', 2)"))
              raise ActiveRecord::Rollback
            end
            counts = [
              conn.select_value("SELECT COUNT(*) FROM #{widgets} WHERE name = 'kept'"),
              conn.select_value("SELECT COUNT(*) FROM #{widgets} WHERE name = 'gone'"),
            ]
            pool.release_connection
            counts
          end

          assert_equal 1, committed
          assert_equal 0, rolled_back
        end

        def test_insert_from_worker_ractor_returns_generated_id
          table = widgets_table
          generated_id = on_ractor(table) do |widgets|
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            inserted_id = conn.insert(Arel.sql("INSERT INTO #{widgets} (name, price) VALUES ('from_worker', 9)"))
            pool.release_connection
            inserted_id
          end

          assert_kind_of Integer, generated_id
          assert_equal generated_id, ActiveRecord::Base.lease_connection.select_value(
            "SELECT id FROM #{widgets_table} WHERE name = 'from_worker'"
          )
        end

        def test_database_error_class_crosses_the_boundary
          error_class, message = on_ractor do
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            begin
              conn.select_value("SELECT * FROM nonexistent_ractor_table")
              ["no error", nil]
            rescue => e
              [e.class.name, e.message]
            ensure
              pool.release_connection
            end
          end

          assert_equal "ActiveRecord::StatementInvalid", error_class
          assert_match(/nonexistent_ractor_table/, message)
        end

        def test_schema_statement_rendering_raises_from_worker_ractor
          error_class, message = on_ractor do
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            begin
              # Probe the rendering choke point directly: DDL methods the
              # concrete adapter overrides (e.g. PostgreSQL's add_index)
              # dispatch the whole call to the main Ractor and never render
              # on the proxy, so only non-overridden methods would reach the
              # guard, adapter-dependently.
              conn.schema_creation.accept(:ractor_ddl_probe)
              ["no error", nil]
            rescue => e
              [e.class.name, e.message]
            ensure
              pool.release_connection
            end
          end

          assert_equal "ActiveRecord::ActiveRecordError", error_class
          assert_match(/main Ractor/, message)
        end

        def test_worker_query_emits_exactly_one_worker_side_notification
          count = on_ractor do
            events = []
            ActiveSupport::Notifications.subscribe("sql.active_record") { |event| events << event.payload[:sql] }
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            conn.select_value("SELECT 482731")
            pool.release_connection
            events.count { |sql| sql.include?("482731") }
          end

          assert_equal 1, count
        end

        def test_worker_query_emits_no_main_side_notification
          main_events = []
          subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |event|
            main_events << event.payload[:sql]
          end
          # Subscribing re-recorded an unshareable snapshot; restore one
          # workers can bootstrap from.
          install_shareable_notifications_snapshot

          on_ractor do
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            conn.select_value("SELECT 482731")
            pool.release_connection
            nil
          end

          assert_empty main_events.grep(/482731/)
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end

        def test_query_transformers_run_exactly_once
          transformer = Ractor.shareable_lambda(self: nil) { |sql, _adapter| sql + " /* transformed */" }
          ActiveRecord.query_transformers = Ractor.make_shareable([transformer])

          sqls = on_ractor do
            events = []
            ActiveSupport::Notifications.subscribe("sql.active_record") { |event| events << event.payload[:sql] }
            pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
            conn = pool.lease_connection
            conn.select_value("SELECT 482731")
            pool.release_connection
            events.select { |sql| sql.include?("482731") }
          end

          assert_equal 1, sqls.length
          assert_equal 1, sqls.first.scan("/* transformed */").length
        end

        def test_multiple_databases_pin_to_the_selected_pool
          ARUnit2Model.lease_connection.select_value("SELECT COUNT(*) FROM courses")
          ActiveRecord::Base.connection_handler.clear_active_connections!

          course_count, courses_known_to_secondary, courses_known_to_primary = on_ractor do
            handler = ConnectionAdapters::RactorConnectionHandler.instance
            secondary_pool = handler.retrieve_connection_pool("ARUnit2Model")
            primary_pool = handler.retrieve_connection_pool("ActiveRecord::Base")

            conn = secondary_pool.lease_connection
            count = conn.select_value("SELECT COUNT(*) FROM courses")
            secondary_pool.release_connection

            [
              count,
              secondary_pool.schema_cache.data_source_exists?("courses"),
              primary_pool.schema_cache.data_source_exists?("courses"),
            ]
          end

          assert_kind_of Integer, course_count
          assert courses_known_to_secondary
          assert_not courses_known_to_primary
        end

        def test_establish_connection_from_worker_with_mutable_config
          database_path = File.join(Dir.tmpdir, "ractor_connection_test_#{Process.pid}.sqlite3")
          selected = on_ractor(database_path) do |path|
            handler = ConnectionAdapters::RactorConnectionHandler.instance
            pool = handler.establish_connection(
              { "adapter" => "sqlite3", "database" => path },
              owner_name: "RactorEstablishedBase",
            )
            conn = pool.lease_connection
            value = conn.select_value("SELECT 7")
            pool.release_connection
            value
          end

          assert_equal 7, selected
        ensure
          File.delete(database_path) if database_path && File.exist?(database_path)
        end

        def test_model_entry_points_work_once_model_state_is_warm
          # Warm the model's memoized class state on the main Ractor first;
          # the worker then reads it and queries through the ordinary model
          # API end to end.
          expected = Topic.count

          result = on_ractor { Topic.count }

          assert_equal expected, result
        end

        def test_cold_model_entry_points_currently_require_shareable_model_state
          # Known prerequisite, deliberately visible: model classes memoize
          # state in class instance variables on first use, which a non-main
          # Ractor cannot write. ColdModel is never touched on the main
          # Ractor, so its first use happens on the worker. Once model state
          # becomes Ractor-shareable this test must be flipped to assert the
          # query result.
          error_class = on_ractor do
            ColdModel.count
            "no error"
          rescue Exception => e
            e.class.name
          end

          assert_equal "Ractor::IsolationError", error_class
        end
      end

      private
        def widgets_table
          @widgets_table ||= "ractor_widgets_#{Process.pid}"
        end

        def create_widgets_table
          ActiveRecord::Base.lease_connection.create_table(widgets_table, force: true) do |t|
            t.string :name
            t.integer :price
          end
          ActiveRecord::Base.connection_handler.clear_active_connections!
        end

        def drop_widgets_table
          ActiveRecord::Base.lease_connection.drop_table(widgets_table, if_exists: true)
        rescue ActiveRecord::ActiveRecordError
          nil
        end

        def proxy_connection
          RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
        end

        def install_shareable_notifications_snapshot
          ActiveSupport::Notifications.notifier_subscriptions = Ractor.make_shareable(
            { string_subscribers: {}, other_subscribers: [] }, copy: true
          )
        end

        def bind_placeholder(position)
          current_adapter?(:PostgreSQLAdapter) ? "$#{position}" : "?"
        end

        # The real main-Ractor pool: `ActiveRecord::Base.connection_pool`
        # resolves to a facade in a self-proxy run.
        def main_pool
          without_ractor_proxy { ActiveRecord::Base.connection_pool }
        end

        def db_config
          main_pool.db_config
        end

        def pool_spec(connection_name: "ActiveRecord::Base", role: :writing, shard: :default, config: db_config)
          {
            db_config: config,
            connection_name: connection_name.to_s.freeze,
            role: role,
            shard: shard,
            # The identity of the main pool this spec names, as spec_for
            # records it; keeps every facade built from this helper sharing
            # one worker-side lease.
            pool_token: RactorConnectionProxy.pool_token(main_pool),
          }
        end
    end
  end
end
