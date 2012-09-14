require "cases/helper"

module ActiveRecord
  class PostgresqlConnectionTest < ActiveRecord::TestCase
    def setup
      super
      @connection = ActiveRecord::Base.connection
    end

    def test_encoding
      assert_not_nil @connection.encoding
    end

    def test_reconnection_after_simulated_disconnection_with_verify
      assert @connection.active?
      original_connection_pid = @connection.query('select pg_backend_pid()')

      # Fail with bad connection on next query attempt.
      raw_connection = @connection.raw_connection
      raw_connection_class = class << raw_connection ; self ; end
      raw_connection_class.class_eval <<-CODE, __FILE__, __LINE__ + 1
        def query_fake(*args)
          if !( @called ||= false )
            self.stubs(:status).returns(PGconn::CONNECTION_BAD)
            @called = true
            raise PGError
          else
            self.unstub(:status)
            query_unfake(*args)
          end
        end

        alias query_unfake query
        alias query        query_fake
      CODE

      begin
        @connection.verify!
        new_connection_pid = @connection.query('select pg_backend_pid()')
      ensure
        raw_connection_class.class_eval <<-CODE
          alias query query_unfake
          undef query_fake
        CODE
      end

      assert_not_equal original_connection_pid, new_connection_pid, "Should have a new underlying connection pid"
    end

    # Must have with_manual_interventions set to true for this
    # test to run.
    # When prompted, restart the PostgreSQL server with the
    # "-m fast" option or kill the individual connection assuming
    # you know the incantation to do that.
    # To restart PostgreSQL 9.1 on OS X, installed via MacPorts, ...
    # sudo su postgres -c "pg_ctl restart -D /opt/local/var/db/postgresql91/defaultdb/ -m fast"
    def test_reconnection_after_actual_disconnection_with_verify
      return skip "with_manual_interventions is false in configuration" unless ARTest.config['with_manual_interventions']

      original_connection_pid = @connection.query('select pg_backend_pid()')

      # Sanity check.
      assert @connection.active?

      puts 'Kill the connection now (e.g. by restarting the PostgreSQL ' +
           'server with the "-m fast" option) and then press enter.'
      $stdin.gets

      @connection.verify!

      assert @connection.active?

      # If we get no exception here, then either we re-connected successfully, or
      # we never actually got disconnected.
      new_connection_pid = @connection.query('select pg_backend_pid()')

      assert_not_equal original_connection_pid, new_connection_pid,
        "umm -- looks like you didn't break the connection, because we're still " +
        "successfully querying with the same connection pid."

      # Repair all fixture connections so other tests won't break.
      @fixture_connections.each do |c|
        c.verify!
      end
    end

  end
end
