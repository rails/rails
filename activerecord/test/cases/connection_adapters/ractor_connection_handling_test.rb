# frozen_string_literal: true

# :markup: markdown

require "cases/helper"
require "active_support/testing/ractors_assertions"
require "models/course"
require "models/topic"

module ActiveRecord
  module ConnectionAdapters
    class RactorConnectionHandlingTest < ActiveRecord::TestCase
      include ActiveSupport::Testing::RactorsAssertions
      include ActiveSupport::Testing::Isolation

      self.use_transactional_tests = false

      setup do
        create_widgets_table
      end

      teardown do
        RactorConnectionHandler::Proxy.checkin_all_connections
        drop_widgets_table
        ActiveRecord::Base.connection_handler.clear_active_connections!
      end

      if !in_memory_db? && RUBY_VERSION >= "4.0"
        class ErrorResponseTest < RactorConnectionHandlingTest
          def test_rebuilds_active_record_errors_with_the_remote_error_as_cause
            original = raised { raise ActiveRecord::StatementInvalid.new("boom", sql: "SELECT 1") }
            response = RactorConnectionHandler::Proxy::ErrorResponse.new(original)
            assert_ractor_shareable(response)

            pool = Object.new
            error = response.exception(connection_pool: pool)
            assert_instance_of ActiveRecord::StatementInvalid, error
            assert_equal "boom", error.message
            assert_equal "SELECT 1", error.sql
            assert_same pool, error.connection_pool
            assert_equal original.backtrace, error.backtrace.first(original.backtrace.size)

            remote = error.cause
            assert_instance_of RactorConnectionHandler::Proxy::RemoteError, remote
            assert_equal ActiveRecord::StatementInvalid, remote.error_class
            assert_equal "boom", remote.message
            assert_equal original.backtrace, remote.backtrace
            assert_nil remote.cause
          end

          def test_rebuilds_only_errors_whose_state_is_plain_data
            error = RactorConnectionHandler::Proxy::ErrorResponse.new(raised { {}.fetch(:ractor_probe) }).exception
            assert_instance_of KeyError, error
            assert_equal "key not found: :ractor_probe", error.message

            error = RactorConnectionHandler::Proxy::ErrorResponse.new(raised { raise Errno::ECONNREFUSED, "db" }).exception
            assert_instance_of RactorConnectionHandler::Proxy::RemoteError, error
            assert_equal Errno::ECONNREFUSED, error.error_class
            assert_equal "Connection refused - db", error.message

            stateless = Class.new(StandardError)
            error = RactorConnectionHandler::Proxy::ErrorResponse.new(raised { raise stateless, "plain" }).exception
            assert_instance_of stateless, error

            stateful = raised { raise stateless, "connection lost" }
            stateful.instance_variable_set(:@connection, Mutex.new)
            error = RactorConnectionHandler::Proxy::ErrorResponse.new(stateful).exception
            assert_instance_of RactorConnectionHandler::Proxy::RemoteError, error
            assert_equal stateless, error.error_class
            assert_equal "connection lost", error.message
            assert_not error.instance_variable_defined?(:@connection)

            unshareable = ActiveRecord::ActiveRecordError.new("pinned")
            unshareable.instance_variable_set(:@lock, Mutex.new)
            assert_raises(Ractor::Error) { RactorConnectionHandler::Proxy::ErrorResponse.new(unshareable) }
          end

          def test_rebuilds_classes_with_custom_constructors
            response = RactorConnectionHandler::Proxy::ErrorResponse.new(
              ActiveRecord::MismatchedForeignKey.new(
                message: "fk mismatch", sql: "ALTER TABLE widgets", query_parser: ->(sql) { { table: sql } }
              )
            )
            assert_ractor_shareable(response)

            error = response.exception
            assert_instance_of ActiveRecord::MismatchedForeignKey, error
            assert_match(/fk mismatch/, error.message)
            assert_equal "ALTER TABLE widgets", error.sql

            query_parser = error.instance_variable_get(:@query_parser)
            assert_ractor_shareable(query_parser)
            assert_predicate query_parser, :lambda?
            assert_equal({ table: "widgets" }, query_parser.call("widgets"))
          end

          def test_transports_the_cause_chain
            driver_error_class = Class.new(StandardError)
            original = raised do
              raise driver_error_class, "no such table"
            rescue => driver_error
              raise ActiveRecord::StatementInvalid.new("boom", sql: "SELECT 1"), cause: driver_error
            end

            response = RactorConnectionHandler::Proxy::ErrorResponse.new(original)
            assert_ractor_shareable(response)

            error = response.exception
            assert_instance_of ActiveRecord::StatementInvalid, error
            assert_equal ActiveRecord::StatementInvalid, error.cause.error_class

            driver_error = error.cause.cause
            assert_instance_of RactorConnectionHandler::Proxy::RemoteError, driver_error
            assert_equal driver_error_class, driver_error.error_class
            assert_equal "no such table", driver_error.message
            assert_equal original.cause.backtrace, driver_error.backtrace
            assert_nil driver_error.cause
          end

          private
            def raised
              yield
              flunk "expected the block to raise"
            rescue => error
              error
            end
        end

        class ProxyConnectionPoolTest < RactorConnectionHandlingTest
          def test_lease_connection_checks_out_once_and_marks_sticky
            pool = proxy_pool

            assert_not pool.active_connection?
            assert pool.permanent_lease?

            conn = pool.lease_connection
            assert_kind_of RactorConnectionHandler::AbstractProxyAdapter, conn
            assert pool.active_connection?
            assert_not pool.permanent_lease?

            assert_same conn, pool.lease_connection
          end

          def test_release_connection_returns_connection_and_clears_lease
            pool = proxy_pool
            pool.lease_connection

            assert pool.release_connection
            assert_not pool.active_connection?
            assert pool.permanent_lease?

            assert_not pool.release_connection
          end

          def test_with_connection_yields_and_releases_when_not_sticky
            pool = proxy_pool

            yielded = nil
            pool.with_connection { |c| yielded = c }

            assert_kind_of RactorConnectionHandler::AbstractProxyAdapter, yielded
            assert_not pool.active_connection?
          end

          def test_with_connection_keeps_lease_when_already_sticky
            pool = proxy_pool
            conn = pool.lease_connection

            pool.with_connection { |c| assert_same conn, c }

            assert pool.active_connection?
          end

          def test_with_connection_prevent_permanent_checkout_releases_a_lease_taken_inside
            pool = proxy_pool

            pool.with_connection(prevent_permanent_checkout: true) do |c|
              assert_same c, pool.lease_connection
            end

            assert_not pool.active_connection?
          end

          def test_query_cache_toggles_and_block_forms_restore_previous_state
            pool = proxy_pool
            assert_not pool.query_cache_enabled
            assert pool.dirties_query_cache

            pool.enable_query_cache { assert pool.query_cache_enabled }
            assert_not pool.query_cache_enabled

            pool.enable_query_cache!
            assert pool.query_cache_enabled

            pool.disable_query_cache { assert_not pool.query_cache_enabled }
            assert pool.query_cache_enabled

            pool.disable_query_cache!
            assert_not pool.query_cache_enabled
          end

          def test_with_pool_transaction_isolation_level_is_a_noop_without_a_default_level
            pool = proxy_pool

            ActiveRecord.with_transaction_isolation_level(nil) do
              observed = :not_yielded
              pool.with_pool_transaction_isolation_level(:serializable, false) do
                observed = pool.pool_transaction_isolation_level
              end
              assert_nil observed
            end
          end

          def test_with_pool_transaction_isolation_level_sets_and_restores
            pool = proxy_pool

            ActiveRecord.with_transaction_isolation_level(:read_committed) do
              observed = nil
              pool.with_pool_transaction_isolation_level(:serializable, false) do
                observed = pool.pool_transaction_isolation_level
              end
              assert_equal :serializable, observed
              assert_nil pool.pool_transaction_isolation_level
            end
          end

          def test_with_pool_transaction_isolation_level_raises_when_transaction_open_and_level_differs
            pool = proxy_pool

            ActiveRecord.with_transaction_isolation_level(:read_committed) do
              pool.pool_transaction_isolation_level = :serializable
              assert_raises(ActiveRecord::TransactionIsolationError) do
                pool.with_pool_transaction_isolation_level(:read_committed, true) { }
              end
            end
          end
        end

        class HandlerTest < RactorConnectionHandlingTest
          def test_connection_pool_list_returns_ractor_pools
            pools = RactorConnectionHandler.instance.connection_pool_list
            assert pools.all? { |p| p.is_a?(RactorConnectionHandler::ProxyConnectionPool) }
            assert_includes pools.map { |p| p.db_config.name }, "primary"
          end

          def test_retrieve_connection_pool_mirrors_the_main_pool
            pool = proxy_pool
            assert_equal "primary", pool.db_config.name
            assert_equal :writing, pool.role
            assert_equal :default, pool.shard
            assert_equal ["ActiveRecord::Base", :writing, :default, main_pool.pool_config.pool_token], pool.key
          end

          def test_unknown_connection_name_has_no_pool_and_is_not_connected
            handler = RactorConnectionHandler.instance
            assert_nil handler.retrieve_connection_pool("Nonexistent::Base")
            assert_not handler.connected?("Nonexistent::Base")
          end

          def test_establish_connection_reuses_the_main_pool_for_a_config_copy
            pool_before = main_pool
            pool = RactorConnectionHandler.instance.establish_connection(pool_before.db_config)

            assert_equal ["ActiveRecord::Base", :writing, :default, pool_before.pool_config.pool_token], pool.key
            assert_same pool_before, main_pool
          end

          def test_clear_active_connections_releases_retrieved_connections
            handler = RactorConnectionHandler.instance
            assert_kind_of RactorConnectionHandler::AbstractProxyAdapter, handler.retrieve_connection("ActiveRecord::Base")
            assert handler.active_connections?
            assert handler.connected?("ActiveRecord::Base")

            handler.clear_active_connections!
            assert_not handler.active_connections?
          end
        end

        class ProxyAdapterTest < RactorConnectionHandlingTest
          def test_reports_concrete_adapter_behavior
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

          def test_caches_capability_lookups
            conn = proxy_connection
            calls = 0
            main_side.define_singleton_method(:supports_ractor_probe?) { calls += 1; true }

            assert conn.supports_ractor_probe?
            assert conn.supports_ractor_probe?
            assert_equal 1, calls
          end

          def test_health_methods_reflect_underlying_connection
            conn = proxy_connection

            assert conn.connected?
            assert conn.active?
            assert_same conn, conn.verify!

            conn.release_connection
            assert_not conn.connected?
            assert_not conn.active?
          end

          def test_pinned_connection_is_marked_proxied_until_released
            conn = proxy_connection
            pinned = main_side

            assert_predicate pinned, :proxied?

            conn.release_connection
            assert_not_predicate pinned, :proxied?
          end

          def test_stale_pinned_connection_does_not_reconnect_away_an_open_transaction
            conn = proxy_connection
            pinned = main_side
            reconnect = ->(**) { raise "the concrete adapter must not reconnect a token-pinned connection on its own" }

            pinned.stub(:reconnect!, reconnect) do
              conn.transaction do
                conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('first', 1)"))

                pinned.instance_variable_set(:@verified, false)
                pinned.instance_variable_set(:@last_activity, nil)
                pinned.stub(:active?, false) do
                  conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('second', 2)"))
                end
              end
            end

            assert_equal ["first", "second"], conn.select_values("SELECT name FROM #{widgets_table} ORDER BY id")
          end

          def test_execute_returns_materialized_result
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

          if current_adapter?(:SQLite3Adapter)
            def test_insert_returns_generated_id_read_from_the_connection
              conn = proxy_connection
              raw_connection = main_side.instance_variable_get(:@raw_connection)
              read_last_id = ->(_result) { raw_connection.last_insert_row_id }

              id = conn.stub(:supports_insert_returning?, false) do
                main_side.stub(:last_inserted_id, read_last_id) do
                  conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('no_returning', 3)"))
                end
              end

              assert_kind_of Integer, id
              assert_equal id, conn.select_value("SELECT id FROM #{widgets_table} WHERE name = 'no_returning'")
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
              assert_no_match(/FOR UPDATE/, sql)
            else
              assert_match(/FOR UPDATE/, sql)
            end

            assert_equal 1, main_pool.connections.size
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

          def test_connection_failure_is_not_retried_without_allow_retry
            conn = proxy_connection
            close_connection(main_side)

            assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
              conn.select_all("SELECT 42")
            end

            assert_equal 1, conn.select_value("SELECT 1")
          end

          def test_allow_retry_reconnects_a_dead_connection_and_restores_clean_transaction_state
            conn = proxy_connection
            pinned = main_side

            conn.transaction do
              conn.materialize_transactions
              close_connection(pinned)

              assert_equal [[42]], conn.select_all("SELECT 42", nil, [], allow_retry: true).rows

              assert pinned.transaction_open?
              conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('retried', 1)"))
            end

            assert_equal ["retried"], conn.select_values("SELECT name FROM #{widgets_table}")
          end

          def test_allow_retry_does_not_retry_inside_a_dirty_transaction
            conn = proxy_connection
            pinned = main_side

            assert_raises(ActiveRecord::ConnectionNotEstablished, ActiveRecord::ConnectionFailed) do
              conn.transaction do
                conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('doomed', 1)"))
                close_connection(pinned)
              end
            end

            assert_equal [], proxy_connection.select_values("SELECT name FROM #{widgets_table}")
          end

          def test_commit_raises_when_the_pool_disconnected_the_pinned_connection_mid_transaction
            conn = proxy_connection
            pinned = main_side

            assert_raises(ActiveRecord::ConnectionNotEstablished) do
              conn.transaction do
                conn.insert(Arel.sql("INSERT INTO #{widgets_table} (name, price) VALUES ('lost', 1)"))
                main_pool.disconnect!
                assert_not pinned.transaction_open?
              end
            end

            assert_not conn.transaction_open?
            assert_equal [], main_pool.with_connection { |c| c.select_values("SELECT name FROM #{widgets_table}") }
          end

          def test_close_returns_connection_to_pool_and_clears_lease
            pool = proxy_pool
            conn = pool.lease_connection

            conn.close

            assert_not pool.active_connection?
            assert_not conn.connected?
            assert_empty RactorConnectionHandler::Proxy.connections

            assert_equal 1, pool.lease_connection.select_value("SELECT 1")
          end

          def test_throw_away_removes_connection_from_both_pools
            conn = proxy_pool.checkout
            pinned = main_side

            conn.throw_away!

            assert_not conn.connected?
            assert_empty RactorConnectionHandler::Proxy.connections
            assert_not_includes main_pool.connections, pinned
          end

          private
            def main_side
              RactorConnectionHandler::Proxy.connections.values.first
            end

            def close_connection(connection)
              connection.instance_variable_get(:@raw_connection).close
            end

            def bind_placeholder(position)
              current_adapter?(:PostgreSQLAdapter) ? "$#{position}" : "?"
            end
        end

        class WorkerRactorTest < RactorConnectionHandlingTest
          class WorkerRactorOnlyModel < ActiveRecord::Base
            self.table_name = "topics"
          end

          setup do
            Ractor.make_shareable(ActiveRecord.query_transformers)
            install_shareable_notifications_snapshot
          end

          def test_select_value_through_automatic_handler
            result = on_ractor do
              ActiveRecord::Base.with_connection { |conn| conn.select_value("SELECT 41 + 1") }
            end
            assert_equal 42, result
          end

          def test_transaction_commit_rollback_and_generated_id
            table = widgets_table
            kept_id, committed, rolled_back = on_ractor(table) do |widgets|
              pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
              pool.with_connection do |conn|
                inserted_id = conn.transaction do
                  conn.insert(Arel.sql("INSERT INTO #{widgets} (name, price) VALUES ('kept', 1)"))
                end
                conn.transaction do
                  conn.insert(Arel.sql("INSERT INTO #{widgets} (name, price) VALUES ('gone', 2)"))
                  raise ActiveRecord::Rollback
                end
                [
                  inserted_id,
                  conn.select_value("SELECT COUNT(*) FROM #{widgets} WHERE name = 'kept'"),
                  conn.select_value("SELECT COUNT(*) FROM #{widgets} WHERE name = 'gone'"),
                ]
              end
            end

            assert_kind_of Integer, kept_id
            assert_equal kept_id, ActiveRecord::Base.lease_connection.select_value("SELECT id FROM #{widgets_table} WHERE name = 'kept'")
            assert_equal 1, committed
            assert_equal 0, rolled_back
          end

          def test_database_errors_cross_the_boundary_with_their_class_and_remote_cause
            driver = driver_error_namespace

            error_class, message, sql, pool_is_workers, cause_chain = on_ractor do
              pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
              pool.with_connection do |conn|
                conn.select_value("SELECT * FROM nonexistent_ractor_table")
                ["no error"]
              rescue => e
                chain = []
                cause = e.cause
                while cause
                  chain << [cause.class.name, cause.error_class.name, cause.message]
                  cause = cause.cause
                end
                [e.class.name, e.message, e.sql, e.connection_pool.equal?(pool), chain]
              end
            end

            assert_equal "ActiveRecord::StatementInvalid", error_class
            assert_match(/nonexistent_ractor_table/, message)
            assert_equal "SELECT * FROM nonexistent_ractor_table", sql
            assert pool_is_workers

            remote_error = RactorConnectionHandler::Proxy::RemoteError.name
            translated, driver_error = cause_chain
            assert_equal 2, cause_chain.size
            assert_equal [remote_error, "ActiveRecord::StatementInvalid"], translated.first(2)
            assert_equal remote_error, driver_error[0]
            assert_equal driver, driver_error[1].split("::").first
            assert_match(/nonexistent_ractor_table/, driver_error[2])
          end

          def test_schema_statement_rendering_raises
            error_class, message = on_ractor do
              pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
              pool.with_connection do |conn|
                conn.schema_creation.accept(:ractor_ddl_probe)
                ["no error"]
              rescue => e
                [e.class.name, e.message]
              end
            end

            assert_equal "ActiveRecord::ActiveRecordError", error_class
            assert_match(/main Ractor/, message)
          end

          def test_query_emits_one_worker_side_notification_with_transformers_applied_once
            transformer = Ractor.shareable_lambda(self: nil) { |sql, _adapter| sql + " /* transformed */" }
            ActiveRecord.query_transformers = Ractor.make_shareable([transformer])

            sqls = on_ractor do
              events = []
              ActiveSupport::Notifications.subscribe("sql.active_record") { |event| events << event.payload[:sql] }
              pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
              pool.with_connection { |conn| conn.select_value("SELECT 482731") }
              events.grep(/482731/)
            end

            assert_equal 1, sqls.length
            assert_equal 1, sqls.first.scan("/* transformed */").length
          end

          def test_query_emits_no_main_side_notification
            main_events = []
            ActiveSupport::Notifications.subscribe("sql.active_record") { |event| main_events << event.payload[:sql] }
            # Subscribing re-recorded an unshareable snapshot.
            install_shareable_notifications_snapshot

            on_ractor do
              pool = ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
              pool.with_connection { |conn| conn.select_value("SELECT 482731") }
              nil
            end

            assert_empty main_events.grep(/482731/)
          end

          def test_multiple_databases_pin_to_the_selected_pool
            ARUnit2Model.lease_connection.select_value("SELECT COUNT(*) FROM courses")
            ActiveRecord::Base.connection_handler.clear_active_connections!

            course_count, courses_known_to_secondary, courses_known_to_primary = on_ractor do
              handler = ConnectionAdapters::RactorConnectionHandler.instance
              secondary_pool = handler.retrieve_connection_pool("ARUnit2Model")
              primary_pool = handler.retrieve_connection_pool("ActiveRecord::Base")

              [
                secondary_pool.with_connection { |conn| conn.select_value("SELECT COUNT(*) FROM courses") },
                secondary_pool.schema_cache.data_source_exists?("courses"),
                primary_pool.schema_cache.data_source_exists?("courses"),
              ]
            end

            assert_kind_of Integer, course_count
            assert courses_known_to_secondary
            assert_not courses_known_to_primary
          end

          def test_establish_connection_accepts_a_hash_or_a_config_object
            database_path = File.join(Dir.tmpdir, "ractor_connection_handling_test_#{Process.pid}.sqlite3")

            selected, adapter_class_name = on_ractor(database_path) do |path|
              handler = ConnectionAdapters::RactorConnectionHandler.instance
              from_hash = handler.establish_connection({ "adapter" => "sqlite3", "database" => path }, owner_name: "RactorEstablishedFromHash")
              config = DatabaseConfigurations::HashConfig.new("arunit", "ractor_established", "adapter" => "sqlite3", "database" => path)
              from_config = handler.establish_connection(config, owner_name: "RactorEstablishedFromConfig")

              values = [from_hash, from_config].map do |pool|
                pool.with_connection { |conn| conn.select_value("SELECT 7") }
              end
              [values, from_config.db_config.adapter_class.name]
            end

            assert_equal [7, 7], selected
            assert_equal "ActiveRecord::ConnectionAdapters::SQLite3Adapter", adapter_class_name
          ensure
            File.delete(database_path) if File.exist?(database_path)
          end

          def test_model_entry_points_work_with_and_without_main_ractor_warmup
            expected = Topic.count

            assert_equal expected, on_ractor { Topic.count }
            assert_equal expected, on_ractor { WorkerRactorOnlyModel.count }
          end

          def test_compiles_arel_locally_matching_the_main_side_compile
            t = Arel::Table.new(name: "topics")
            ast = t.project(Arel.star).where(t[:id].eq(Arel::Nodes::BindParam.new(1))).ast
            expected = without_ractor_proxy do
              ActiveRecord::Base.lease_connection.to_sql_and_binds(ast)
            end

            compiled = on_ractor do
              table = Arel::Table.new(name: "topics")
              arel = table.project(Arel.star).where(table[:id].eq(Arel::Nodes::BindParam.new(1))).ast
              ActiveRecord::Base.with_connection { |conn| conn.to_sql_and_binds(arel) }
            end

            assert_equal expected, compiled
          end

          def test_checkin_all_connections_releases_stranded_tokens
            on_ractor do
              ConnectionAdapters::RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base").lease_connection
              nil
            end

            assert_equal 1, RactorConnectionHandler::Proxy.connections.size
            RactorConnectionHandler::Proxy.checkin_all_connections
            assert_empty RactorConnectionHandler::Proxy.connections
          end

          private
            def install_shareable_notifications_snapshot
              ActiveSupport::Notifications.notifier_subscriptions = Ractor.make_shareable(
                { string_subscribers: {}, other_subscribers: [] }, copy: true
              )
            end

            def driver_error_namespace
              error = assert_raises(ActiveRecord::StatementInvalid) do
                main_pool.with_connection { |connection| connection.select_value("SELECT * FROM nonexistent_ractor_table") }
              end
              error.cause.class.name.split("::").first
            end
        end
      end

      private
        def widgets_table
          @widgets_table ||= "ractor_widgets_#{Process.pid}"
        end

        def create_widgets_table
          without_ractor_proxy do
            ActiveRecord::Base.lease_connection.create_table(widgets_table, force: true) do |t|
              t.string :name
              t.integer :price
            end
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end

        def drop_widgets_table
          ActiveRecord::Base.lease_connection.drop_table(widgets_table, if_exists: true)
        rescue ActiveRecord::ActiveRecordError
          nil
        end

        def main_pool
          without_ractor_proxy { ActiveRecord::Base.connection_pool }
        end

        def proxy_pool
          RactorConnectionHandler.instance.retrieve_connection_pool("ActiveRecord::Base")
        end

        def proxy_connection
          RactorConnectionHandler.instance.retrieve_connection("ActiveRecord::Base")
        end
    end
  end
end
