require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class AutoReconnectionTest < ActiveRecord::TestCase
        self.use_transactional_fixtures = false

        def setup
          @conn = ActiveRecord::Base.connection
        end

        def test_invoke_once_on_success
          call_count = 0
          @conn.send(:with_auto_reconnect){
            call_count += 1
          }
          assert_equal 1, call_count
        end

        def test_return_block_value_on_success
          result = @conn.send(:with_auto_reconnect) do
            :the_result
          end
          assert_equal :the_result, result
        end

        def test_invoke_once_on_statement_invalid_with_good_connection
          call_count = 0
          assert_raise StatementInvalid do
            @conn.send(:with_auto_reconnect) do
              call_count += 1
              raise StatementInvalid
            end
          end
          assert_equal 1, call_count
        end

        def test_invoke_once_on_statement_invalid_with_bad_connection_in_transaction
          @conn.raw_connection.stubs(:status).returns(PG::CONNECTION_BAD)
          @conn.stubs(:open_transactions).returns(1)

          call_count = 0
          assert_raise StatementInvalid do
            @conn.send(:with_auto_reconnect) do
              call_count += 1
              raise StatementInvalid
            end
          end
          assert_equal 1, call_count
        end

        def test_invoke_once_on_general_error_with_bad_connection
          call_count = 0
          assert_raise StandardError do
            @conn.send(:with_auto_reconnect) do
              call_count += 1
              raise StandardError
            end
          end
          assert_equal 1, call_count
        end

        def test_retry_once_on_persistent_statement_invalid_with_bad_connection
          @conn.raw_connection.stubs(:status).returns(PG::CONNECTION_BAD)

          @conn.expects(:reconnect!)

          call_count = 0
          assert_raise StatementInvalid do
            @conn.send(:with_auto_reconnect) do
              call_count += 1
              raise StatementInvalid
            end
          end
          assert_equal 2, call_count
        end

        def test_retry_once_and_return_result_with_initial_bad_connection
          @conn.raw_connection.stubs(:status).returns(PG::CONNECTION_BAD)

          @conn.expects(:reconnect!)

          call_count = 0
          result = @conn.send(:with_auto_reconnect){
            call_count += 1
            raise StatementInvalid if call_count == 1
            :the_result
          }
          assert_equal 2, call_count
          assert_equal result, :the_result
        end

        # When prompted, restart the PostgreSQL server with the "-m fast" option
        # or kill the individual connection assuming you know the incantation to
        # do that.
        # To restart PostgreSQL 9.1 on OS X, installed via MacPorts, ...
        # sudo su postgres -c "pg_ctl restart -D /opt/local/var/db/postgresql91/defaultdb/ -m fast"
        def test_reconnect_with_actual_killed_connection
          skip "with_manual_interventions is false in configuration" unless ARTest.config['with_manual_interventions']

          original_connection_pid = @conn.query('select pg_backend_pid()')

          puts 'Kill the connection now (e.g. by restarting the PostgreSQL ' +
               'server with the "-m fast" option) and then press enter.'
          $stdin.gets

          # If we get no exception here, then either we re-connected successfully, or
          # we never actually got disconnected.
          new_connection_pid = @conn.query('select pg_backend_pid()')

          assert_not_equal original_connection_pid, new_connection_pid,
            "umm -- looks like you didn't break the connection, because we're still " +
            "successfully querying with the same connection pid."
        end
      end
    end
  end
end
