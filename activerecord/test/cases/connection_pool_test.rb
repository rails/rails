# frozen_string_literal: true

require "cases/helper"
require "concurrent/atomic/count_down_latch"

module ActiveRecord
  module ConnectionAdapters
    module ConnectionPoolTests
      def self.included(test)
        super
        test.use_transactional_tests = false
      end

      attr_reader :pool

      def setup
        # Keep a duplicate pool so we do not bother others
        config = ActiveRecord::Base.connection_pool.db_config
        @db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(
          config.env_name,
          config.name,
          config.configuration_hash.merge(
            checkout_timeout: 0.2, # Reduce checkout_timeout to speedup tests
          )
        )

        @pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, @db_config, :writing, :default)
        @pool = ConnectionPool.new(@pool_config)

        @pools = [@pool]

        if in_memory_db?
          # Separate connections to an in-memory database create an entirely new database,
          # with an empty schema etc, so we just stub out this schema on the fly.
          @pool.with_connection do |connection|
            connection.create_table :posts do |t|
              t.integer :cololumn
            end
          end
        end
      end

      def teardown
        super
        @pools&.each(&:disconnect!)
      end

      def test_checkout_after_close
        connection = pool.lease_connection
        assert_predicate connection, :in_use?

        connection.close
        assert_not_predicate connection, :in_use?

        assert_predicate pool.lease_connection, :in_use?
      end

      def test_released_connection_moves_between_threads
        thread_conn = nil

        new_thread {
          pool.with_connection do |conn|
            thread_conn = conn
          end
        }.join

        assert thread_conn

        new_thread {
          pool.with_connection do |conn|
            assert_equal thread_conn, conn
          end
        }.join
      end

      def test_with_connection
        assert_equal 0, active_connections(pool).size

        main_thread = pool.lease_connection
        assert_equal 1, active_connections(pool).size

        new_thread {
          pool.with_connection do |conn|
            assert conn
            assert_equal 2, active_connections(pool).size
          end
          assert_equal 1, active_connections(pool).size

          pool.with_connection do |conn|
            assert conn
            assert_equal 2, active_connections(pool).size
            pool.lease_connection
          end

          assert_equal 2, active_connections(pool).size
          pool.release_connection
          assert_equal 1, active_connections(pool).size
        }.join

        main_thread.close
        assert_equal 0, active_connections(pool).size
      end

      def test_new_connection_no_query
        skip("Can't test with in-memory dbs") if in_memory_db?
        assert_equal 0, pool.connections.size
        pool.with_connection { |_conn| } # warm the schema cache
        pool.flush(0)
        assert_equal 0, pool.connections.size

        assert_no_queries do
          pool.with_connection { |_conn| }
        end
      end

      def test_active_connection_in_use
        assert_not_predicate pool, :active_connection?
        main_thread = pool.lease_connection

        assert_predicate pool, :active_connection?

        main_thread.close

        assert_not_predicate pool, :active_connection?
      end

      def test_full_pool_exception
        @pool.checkout_timeout = 0.001 # no need to delay test suite by waiting the whole full default timeout
        @pool.size.times { assert @pool.checkout }

        error = assert_raises(ConnectionTimeoutError) do
          @pool.checkout
        end
        assert_equal @pool, error.connection_pool
      end

      def test_full_pool_blocks
        skip_fiber_testing
        cs = @pool.size.times.map { @pool.checkout }
        t = new_thread { @pool.checkout }

        # make sure our thread is in the timeout section
        pass_to(t) until @pool.num_waiting_in_queue == 1

        connection = cs.first
        connection.close
        assert_equal connection, t.join.value
      end

      def test_full_pool_blocking_shares_load_interlock
        skip_fiber_testing
        @pool.instance_variable_set(:@max_connections, 1)

        load_interlock_latch = Concurrent::CountDownLatch.new
        connection_latch = Concurrent::CountDownLatch.new

        able_to_get_connection = false
        able_to_load = false

        thread_with_load_interlock = new_thread do
          ActiveSupport::Dependencies.interlock.running do
            load_interlock_latch.count_down
            connection_latch.wait

            @pool.with_connection do
              able_to_get_connection = true
            end
          end
        end

        thread_with_last_connection = new_thread do
          @pool.with_connection do
            connection_latch.count_down
            load_interlock_latch.wait

            assert_deprecated(/ActiveSupport::Dependencies::Interlock#loading is deprecated/, ActiveSupport.deprecator) do
              ActiveSupport::Dependencies.interlock.loading do
                able_to_load = true
              end
            end
          end
        end

        thread_with_load_interlock.join
        thread_with_last_connection.join

        assert able_to_get_connection
        assert able_to_load
      end

      def test_removing_releases_latch
        skip_fiber_testing
        cs = @pool.size.times.map { @pool.checkout }
        t = new_thread { @pool.checkout }

        # make sure our thread is in the timeout section
        pass_to(t) until @pool.num_waiting_in_queue == 1

        connection = cs.first
        @pool.remove connection
        assert_respond_to t.join.value, :execute
        connection.close
      end

      def test_reap_and_active
        @pool.checkout
        @pool.checkout
        @pool.checkout

        connections = @pool.connections.dup

        @pool.reap

        assert_equal connections.length, @pool.connections.length
      end

      def test_reap_inactive
        ready = Concurrent::CountDownLatch.new
        @pool.checkout
        child = new_thread do
          @pool.checkout
          @pool.checkout
          ready.count_down
          stop_thread
        end
        pass_to(child) until ready.wait(0)

        assert_equal 3, active_connections(@pool).size

        child.terminate
        child.join
        @pool.reap

        assert_equal 1, active_connections(@pool).size
      ensure
        @pool.connections.each { |conn| conn.close if conn.in_use? }
      end

      def test_inactive_are_returned_from_dead_thread
        ready = Concurrent::CountDownLatch.new
        @pool.instance_variable_set(:@max_connections, 1)

        child = new_thread do
          @pool.checkout
          ready.count_down
          stop_thread
        end

        pass_to(child) until ready.wait(0)

        assert_equal 1, active_connections(@pool).size

        child.terminate
        child.join

        @pool.checkout

        assert_equal 1, active_connections(@pool).size
      ensure
        @pool.connections.each { |conn| conn.close if conn.in_use? }
      end

      def test_idle_timeout_configuration
        @pool.disconnect!

        @pool = new_pool_with_options(idle_timeout: "200")
        idle_conn = @pool.checkout
        @pool.checkin(idle_conn)

        idle_conn.instance_variable_set(
          :@idle_since,
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - 199
        )

        @pool.flush
        assert_equal 1, @pool.connections.length

        idle_conn.instance_variable_set(
          :@idle_since,
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - 201
        )

        @pool.flush
        assert_equal 0, @pool.connections.length
      end

      def test_min_connections_configuration
        @pool.disconnect!

        @pool = new_pool_with_options(min_connections: 1)

        @pool.activate
        @pool.prepopulate
        assert_equal 1, @pool.connections.length
      end

      def test_idle_timeout_configuration_with_min_connections
        @pool.disconnect!

        @pool = new_pool_with_options(idle_timeout: "200", min_connections: 1)
        connections = 2.times.map { @pool.checkout }
        connections.each { |conn| @pool.checkin(conn) }

        connections.each do |conn|
          conn.instance_variable_set(
            :@idle_since,
            Process.clock_gettime(Process::CLOCK_MONOTONIC) - 199
          )
        end

        @pool.flush
        assert_equal 2, @pool.connections.length

        connections.each do |conn|
          conn.instance_variable_set(
            :@idle_since,
            Process.clock_gettime(Process::CLOCK_MONOTONIC) - 201
          )
        end

        @pool.flush
        assert_equal 1, @pool.connections.length
      end

      def test_disable_flush
        @pool.disconnect!

        @pool = new_pool_with_options(idle_timeout: -5)
        idle_conn = @pool.checkout
        @pool.checkin(idle_conn)

        idle_conn.instance_variable_set(
          :@idle_since,
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1
        )

        @pool.flush
        assert_equal 1, @pool.connections.length
      end

      def test_flush
        idle_conn = @pool.checkout
        recent_conn = @pool.checkout
        active_conn = @pool.checkout

        @pool.checkin idle_conn
        @pool.checkin recent_conn

        assert_equal 3, @pool.connections.length

        idle_conn.instance_variable_set(
          :@idle_since,
          Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1000
        )

        @pool.flush(30)

        assert_equal 2, @pool.connections.length

        assert_equal [recent_conn, active_conn].sort_by(&:__id__), @pool.connections.sort_by(&:__id__)
      ensure
        @pool.checkin active_conn
      end

      def test_flush_bang
        idle_conn = @pool.checkout
        recent_conn = @pool.checkout
        active_conn = @pool.checkout
        _dead_conn = new_thread { @pool.checkout }.join

        @pool.checkin idle_conn
        @pool.checkin recent_conn

        assert_equal 4, @pool.connections.length

        def idle_conn.seconds_idle
          1000
        end

        @pool.flush!

        assert_equal 1, @pool.connections.length

        assert_equal [active_conn].sort_by(&:__id__), @pool.connections.sort_by(&:__id__)
      ensure
        @pool.checkin active_conn
      end

      def test_automatic_activation
        assert_not_predicate @pool, :activated?

        # Checkout on root thread does not activate the pool
        own_conn = @pool.checkout

        assert_not_predicate @pool, :activated?

        new_thread do
          # Checkout on new thread activates the pool
          conn = @pool.checkout

          assert_predicate @pool, :activated?
          @pool.checkin conn
        end.join

        @pool.checkin own_conn

        # Pool remains activated
        assert_predicate @pool, :activated?

        # flush! deactivates the pool
        @pool.flush!

        assert_not_predicate @pool, :activated?

        new_thread do
          @pool.checkin(@pool.checkout)
        end.join

        # Off-thread checkout re-activates
        assert_predicate @pool, :activated?
      end

      def test_prepopulate
        pool = new_pool_with_options(min_connections: 3, max_connections: 3, async: false)

        assert_equal 0, pool.connections.length
        assert_not_predicate pool, :activated?

        # Pool is not activated, so prepopulate is a no-op
        pool.prepopulate

        assert_equal 0, pool.connections.length
        pool.activate

        assert_predicate pool, :activated?
        pool.prepopulate

        assert_equal 3, pool.connections.length
      end

      def test_preconnect
        pool = new_pool_with_options(min_connections: 3, max_connections: 3, async: false)
        pool.activate
        pool.prepopulate

        assert_equal 3, pool.connections.length
        pool.connections.each do |conn|
          assert_not_predicate conn, :connected?
        end

        pool.preconnect

        assert_equal 3, pool.connections.length
        pool.connections.each do |conn|
          assert_predicate conn, :connected?
        end
      end

      def test_prepopulated_connections_have_allow_preconnect_true
        pool = new_pool_with_options(min_connections: 2, max_connections: 5, async: false)
        pool.activate
        pool.prepopulate

        assert_equal 2, pool.connections.length
        pool.connections.each do |conn|
          assert_equal true, conn.allow_preconnect
        end
      end

      def test_normal_checkout_connections_have_allow_preconnect_false
        pool = new_pool_with_options(min_connections: 0, max_connections: 5, async: false)
        pool.activate

        conn = pool.checkout
        assert_equal false, conn.allow_preconnect
      ensure
        pool.checkin(conn) if conn
      end

      def test_preconnect_only_connects_allow_preconnect_connections
        pool = new_pool_with_options(min_connections: 2, max_connections: 5, async: false)
        pool.activate
        pool.prepopulate

        # Prepopulated connections should have allow_preconnect = true
        assert_equal 2, pool.connections.length

        # Checkout all prepopulated connections to force creation of a new one
        conn1 = pool.checkout
        conn2 = pool.checkout

        # Now checkout will create a new connection (allow_preconnect = false)
        conn3 = pool.checkout
        assert_equal false, conn3.allow_preconnect

        # Return them all
        pool.checkin(conn1)
        pool.checkin(conn2)
        pool.checkin(conn3)

        # Verify we have 3 total connections now
        assert_equal 3, pool.connections.length

        # None should be connected yet
        pool.connections.each do |c|
          assert_not_predicate c, :connected?
        end

        # Run preconnect
        pool.preconnect

        # Only the 2 prepopulated connections (with allow_preconnect = true) should be connected
        connected_count = pool.connections.count(&:connected?)
        assert_equal 2, connected_count

        # The normal checkout connection should still not be connected
        assert_not_predicate conn3, :connected?
      end

      def test_max_age
        pool = new_pool_with_options(max_age: 10, pool_jitter: 0, async: false)

        conn = pool.checkout

        assert_not_predicate conn, :connected?
        assert_nil conn.connection_age

        conn.connect!

        assert_predicate conn, :connected?
        assert_operator conn.connection_age, :>=, 0
        assert_operator conn.connection_age, :<, 1

        conn.instance_variable_set(:@connected_since, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 11)

        assert_operator conn.connection_age, :>, 10

        pool.checkin conn
        pool.retire_old_connections

        assert_not_predicate conn, :connected?
      end

      def test_max_age_with_jitter
        pool = new_pool_with_options(max_age: 20, pool_jitter: 0, async: false)

        conn = pool.checkout
        conn.instance_variable_set(:@pool_jitter, 0.5)

        assert_not_predicate conn, :connected?
        assert_nil conn.connection_age

        conn.connect!

        assert_predicate conn, :connected?
        assert_operator conn.connection_age, :>=, 0
        assert_operator conn.connection_age, :<, 1

        conn.instance_variable_set(:@connected_since, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 11)

        assert_operator conn.connection_age, :>, 10

        pool.checkin conn
        pool.retire_old_connections

        assert_not_predicate conn, :connected?
      end

      def test_jitter_calculated_on_new_connections
        pool = new_pool_with_options(max_age: 10, pool_jitter: 0.5, async: false)

        conns = 4.times.map { pool.checkout }

        observed_jitters = conns.map { |conn| conn.instance_variable_get(:@pool_jitter) }

        assert_operator observed_jitters.min, :>=, 0.0
        assert_operator observed_jitters.max, :>, 0.0 # statistically impossible to get all zeros
        assert_operator observed_jitters.max, :<=, 0.5
      end

      def test_jitter_evaluation
        pool = new_pool_with_options(max_age: 10, pool_jitter: 0.5, async: false)
        conn = pool.checkout

        conn.instance_variable_set(:@pool_jitter, 0.25)

        assert_equal 75, conn.pool_jitter(100)
      end

      def test_explicit_retirement
        pool = new_pool_with_options(max_age: nil, async: false)

        conn = pool.checkout

        assert_not_predicate conn, :connected?
        assert_nil conn.connection_age

        conn.connect!

        assert_predicate conn, :connected?
        assert_operator conn.connection_age, :>=, 0
        assert_operator conn.connection_age, :<, 1

        pool.recycle!

        assert_equal Float::INFINITY, conn.connection_age

        pool.checkin conn
        pool.retire_old_connections

        assert_not_predicate conn, :connected?
      end

      def test_keepalive
        pool = new_pool_with_options(keepalive: 100, pool_jitter: 0, async: false)
        conn = pool.checkout
        conn.connect!
        pool.checkin conn

        assert_operator conn.seconds_since_last_activity, :<, 5

        conn.instance_variable_set(:@last_activity, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 50)

        assert_in_epsilon 50, conn.seconds_since_last_activity, 10

        # we're currently below the threshold, so this is a no-op
        pool.keep_alive

        # still about the same age
        assert_in_epsilon 50, conn.seconds_since_last_activity, 10

        conn.instance_variable_set(:@last_activity, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 150)

        pool.keep_alive

        # keep-alive query occurred, so our activity time has reset
        assert_operator conn.seconds_since_last_activity, :<, 5
      end

      def test_keepalive_with_jitter
        pool = new_pool_with_options(keepalive: 200, pool_jitter: 0, async: false)
        conn = pool.checkout
        conn.instance_variable_set(:@pool_jitter, 0.5)
        conn.connect!
        pool.checkin conn

        assert_operator conn.seconds_since_last_activity, :<, 5

        conn.instance_variable_set(:@last_activity, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 50)

        assert_in_epsilon 50, conn.seconds_since_last_activity, 10

        # we're currently below the threshold, so this is a no-op
        pool.keep_alive

        # still about the same age
        assert_in_epsilon 50, conn.seconds_since_last_activity, 10

        conn.instance_variable_set(:@last_activity, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 150)

        pool.keep_alive

        # keep-alive query occurred, so our activity time has reset
        assert_operator conn.seconds_since_last_activity, :<, 5
      end

      def test_keepalive_notices_problems
        pool = new_pool_with_options(keepalive: 100, pool_jitter: 0, async: false)
        conn = pool.checkout
        conn.connect!
        pool.checkin conn

        original_broken_connection = conn.instance_variable_get(:@raw_connection)

        assert_predicate conn, :connected?

        # This is a definite API violation -- several nearby tests overstep by
        # poking around unowned connections' bookkeeping, but actually querying
        # (as #remote_disconnect does) without owning the connection is extreme.
        # In practice, though, it should be fine: the pool belongs to this test,
        # so the only other thread we could be competing with is the pool's
        # reaper.
        remote_disconnect conn

        assert_same original_broken_connection, conn.instance_variable_get(:@raw_connection)

        # we're below the threshold; no keep-alive occurs
        pool.keep_alive

        # connection is still [unknowingly] broken
        assert_same original_broken_connection, conn.instance_variable_get(:@raw_connection)
        assert_predicate conn, :connected?
        assert_not_predicate conn, :active?

        conn.instance_variable_set(:@last_activity, Process.clock_gettime(Process::CLOCK_MONOTONIC) - 200)
        pool.keep_alive

        # keep-alive noticed the problem and disconnected
        assert_not_predicate conn, :connected?

        # .. so now preconnect can repair the connection
        pool.preconnect

        assert_not_same original_broken_connection, conn.instance_variable_get(:@raw_connection)
        assert_predicate conn, :connected?
        assert_predicate conn, :active?
      end

      def test_idle_through_keepalive
        pool = new_pool_with_options(keepalive: 0.1, pool_jitter: 0, idle_timeout: 0.5, async: false, reaping_frequency: 30)
        conn = pool.checkout
        conn.connect!
        pool.checkin conn

        assert_predicate conn, :connected?
        assert_operator conn.seconds_since_last_activity, :<, 0.1
        assert_operator conn.seconds_idle, :<, 0.1

        # This test is about the interaction between multiple "last use"
        # timers, so manual fudging is a bit too intimate / relies on
        # knowledge of the implementation. So instead, we have to live
        # with a bit of sleeping (and hope we don't lose any races).

        sleep 0.2

        assert_operator conn.seconds_since_last_activity, :>, 0.1
        assert_operator conn.seconds_idle, :>, 0.1
        assert_operator conn.seconds_idle, :<, 0.5

        pool.keep_alive # sends a keep-alive query
        pool.flush # no-op

        assert_predicate conn, :connected?
        assert_operator conn.seconds_since_last_activity, :<, 0.1
        assert_operator conn.seconds_idle, :>, 0.1
        assert_operator conn.seconds_idle, :<, 0.5

        sleep 0.4

        assert_predicate conn, :connected?
        assert_operator conn.seconds_since_last_activity, :>, 0.1
        assert_operator conn.seconds_idle, :>, 0.5

        pool.keep_alive # sends another query, though it doesn't matter
        pool.flush # drops the idle connection

        assert_not_predicate conn, :connected?
      end

      def test_remove_connection
        conn = @pool.checkout
        assert_predicate conn, :in_use?

        length = @pool.connections.length
        @pool.remove conn
        assert_predicate conn, :in_use?
        assert_equal(length - 1, @pool.connections.length)
      ensure
        conn.close
      end

      def test_remove_connection_for_thread
        conn = @pool.lease_connection
        @pool.remove conn
        assert_not_equal(conn, @pool.lease_connection)
      ensure
        conn.close if conn
      end

      def test_active_connection?
        assert_not_predicate @pool, :active_connection?
        assert @pool.lease_connection
        assert_predicate @pool, :active_connection?
        @pool.release_connection
        assert_not_predicate @pool, :active_connection?
      end

      def test_checkout_behavior
        pool = ConnectionPool.new(@pool_config)
        main_connection = pool.lease_connection
        assert_not_nil main_connection
        threads = []
        4.times do |i|
          threads << new_thread(i) do
            thread_connection = pool.lease_connection
            assert_not_nil thread_connection
            thread_connection.close
          end
        end

        threads.each(&:join)

        new_thread do
          assert pool.lease_connection
          pool.lease_connection.close
        end.join
      ensure
        pool&.disconnect!
      end

      def test_checkout_order_is_lifo
        conn1 = @pool.checkout
        conn2 = @pool.checkout
        @pool.checkin conn1
        @pool.checkin conn2
        assert_equal [conn2, conn1], 2.times.map { @pool.checkout }
      end

      # The connection pool is "fair" if threads waiting for
      # connections receive them in the order in which they began
      # waiting.  This ensures that we don't timeout one HTTP request
      # even while well under capacity in a multi-threaded environment
      # such as a Java servlet container.
      #
      # We don't need strict fairness: if two connections become
      # available at the same time, it's fine if two threads that were
      # waiting acquire the connections out of order.
      #
      # Thus this test prepares waiting threads and then trickles in
      # available connections slowly, ensuring the wakeup order is
      # correct in this case.
      def test_checkout_fairness
        skip_fiber_testing

        @pool.instance_variable_set(:@max_connections, 10)
        expected = (1..@pool.size).to_a.freeze
        # check out all connections so our threads start out waiting
        conns = expected.map { @pool.checkout }
        mutex = Mutex.new
        order = []
        errors = []
        dispose_held_connections = Concurrent::Event.new

        threads = expected.map do |i|
          t = new_thread {
            begin
              @pool.checkout # never checked back in
              mutex.synchronize { order << i }

              # if the thread terminates, its connection may be
              # reclaimed by the pool, so we need to hold on to it
              # until we're done trickling in connections
              dispose_held_connections.wait
            rescue => e
              mutex.synchronize { errors << e }
            end
          }
          pass_to(t) until @pool.num_waiting_in_queue == i
          t
        end

        # this should wake up the waiting threads one by one in order
        conns.each { |conn| @pool.checkin(conn); sleep 0.01 }

        dispose_held_connections.set
        threads.each(&:join)

        raise errors.first if errors.any?

        assert_equal(expected, order)
      end

      # As mentioned in #test_checkout_fairness, we don't care about
      # strict fairness.  This test creates two groups of threads:
      # group1 whose members all start waiting before any thread in
      # group2.  Enough connections are checked in to wakeup all
      # group1 threads, and the fact that only group1 and no group2
      # threads acquired a connection is enforced.
      def test_checkout_fairness_by_group
        skip_fiber_testing

        @pool.instance_variable_set(:@max_connections, 10)
        # take all the connections
        conns = (1..10).map { @pool.checkout }
        mutex = Mutex.new
        successes = []    # threads that successfully got a connection
        errors = []
        dispose_held_connections = Concurrent::Event.new

        make_thread = proc do |i|
          t = new_thread {
            begin
              @pool.checkout # never checked back in
              mutex.synchronize { successes << i }

              dispose_held_connections.wait
            rescue => e
              mutex.synchronize { errors << e }
            end
          }
          pass_to(t) until @pool.num_waiting_in_queue == i
          t
        end

        # all group1 threads start waiting before any in group2
        group1 = (1..5).map(&make_thread)
        group2 = (6..10).map(&make_thread)

        # checkin n connections back to the pool
        checkin = proc do |n|
          n.times do
            c = conns.pop
            @pool.checkin(c)
          end
        end

        checkin.call(group1.size)         # should wake up all group1

        loop do
          sleep 0.1
          break if mutex.synchronize { (successes.size + errors.size) == group1.size }
        end

        winners = mutex.synchronize { successes.dup }
        checkin.call(group2.size)         # should wake up everyone remaining

        dispose_held_connections.set
        group1.each(&:join)
        group2.each(&:join)

        assert_equal((1..group1.size).to_a, winners.sort)

        if errors.any?
          raise errors.first
        end
      end

      def test_automatic_reconnect_restores_after_disconnect
        pool = ConnectionPool.new(@pool_config)
        assert pool.automatic_reconnect
        assert pool.lease_connection

        pool.disconnect!
        assert pool.lease_connection
      ensure
        pool&.disconnect!
      end

      def test_automatic_reconnect_can_be_disabled
        pool = ConnectionPool.new(@pool_config)
        pool.disconnect!
        pool.automatic_reconnect = false

        assert_raises(ConnectionNotEstablished) do
          pool.lease_connection
        end

        assert_raises(ConnectionNotEstablished) do
          pool.with_connection
        end
      ensure
        pool&.disconnect!
      end

      def test_pool_sets_connection_visitor
        assert @pool.lease_connection.visitor.is_a?(Arel::Visitors::ToSql)
      end

      #--
      # This is testing a private method... but testing its public
      # callers would be much more complicated, as well as needing
      # duplicate coverage.
      def test_sequential_maintenance_loop_is_incremental
        work_queue = []
        work_collector = Object.new
        work_collector.define_singleton_method(:post) do |&block|
          work_queue << block
        end

        completion_list = []
        selection_list = []

        @pool.instance_variable_set(:@max_connections, 3)
        @pool.instance_variable_set(:@async_executor, work_collector)

        3.times.map { @pool.checkout }.each do |conn|
          @pool.checkin conn
        end

        selector = lambda do |conn|
          assert_not_predicate conn, :in_use?
          assert_equal 3, @pool.num_available_in_queue

          selection_list << conn
          true
        end

        pool.send(:sequential_maintenance, selector) do |conn|
          assert_predicate conn, :in_use?
          assert_equal 2, @pool.num_available_in_queue

          completion_list << conn
        end

        # final iteration determines there's no more work to do
        4.times do
          assert_equal 1, work_queue.size
          work_queue.shift.call
          assert_equal 3, @pool.num_available_in_queue
        end
        assert_equal 0, work_queue.size

        assert_equal 3, completion_list.size
        assert_equal 3 * 4, selection_list.size
      end

      def test_sequential_maintenance_can_run_inline
        completion_list = []
        selection_list = []

        @pool.instance_variable_set(:@max_connections, 3)
        @pool.instance_variable_set(:@async_executor, nil)

        3.times.map { @pool.checkout }.each do |conn|
          @pool.checkin conn
        end

        selector = lambda do |conn|
          assert_not_predicate conn, :in_use?
          assert_equal 3, @pool.num_available_in_queue

          selection_list << conn
          true
        end

        pool.send(:sequential_maintenance, selector) do |conn|
          assert_predicate conn, :in_use?
          assert_equal 2, @pool.num_available_in_queue

          completion_list << conn
        end

        assert_equal 3, @pool.num_available_in_queue

        assert_equal 3, completion_list.size

        # final iteration determines there's no more work to do
        assert_equal 3 * 4, selection_list.size
      end

      # make sure exceptions are thrown when establish_connection
      # is called with an anonymous class
      def test_anonymous_class_exception
        anonymous = Class.new(ActiveRecord::Base)

        assert_raises(RuntimeError) do
          anonymous.establish_connection
        end
      end

      def test_connection_notification_is_called
        payloads = []
        subscription = ActiveSupport::Notifications.subscribe("!connection.active_record") do |name, started, finished, unique_id, payload|
          payloads << payload
        end

        @connection_test_model_class.establish_connection :arunit

        assert_equal [:config, :connection_name, :role, :shard], payloads[0].keys.sort
        assert_equal @connection_test_model_class.name, payloads[0][:connection_name]
        assert_equal ActiveRecord::Base.default_shard, payloads[0][:shard]
        assert_equal :writing, payloads[0][:role]
      ensure
        @connection_test_model_class.remove_connection
        ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      end

      def test_connection_notification_is_called_for_shard
        payloads = []
        subscription = ActiveSupport::Notifications.subscribe("!connection.active_record") do |name, started, finished, unique_id, payload|
          payloads << payload
        end
        @connection_test_model_class.connects_to shards: { default: { writing: :arunit } }

        assert_equal [:config, :connection_name, :role, :shard], payloads[0].keys.sort
        assert_equal @connection_test_model_class.name, payloads[0][:connection_name]
        assert_equal :default, payloads[0][:shard]
        assert_equal :writing, payloads[0][:role]
      ensure
        @connection_test_model_class.remove_connection
        ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      end

      def test_sets_pool_schema_reflection
        pool.schema_cache.add(:posts)
        assert pool.schema_cache.cached?(:posts)

        pool.schema_reflection = SchemaReflection.new("does-not-exist")
        assert_not pool.schema_cache.cached?(:posts)

        pool.schema_cache.add(:posts)
        assert pool.schema_cache.cached?(:posts)
      end

      def test_pool_sets_connection_schema_cache
        pool.schema_cache.add(:posts)
        connection = pool.checkout

        pool.with_connection do |conn|
          # We've retrieved a second, distinct, connection from the pool
          assert_not_same connection, conn

          # But the new connection can already see the schema cache
          # entry we added above
          assert_equal connection.schema_cache.size, conn.schema_cache.size
          assert_same connection.schema_cache.columns(:posts), conn.schema_cache.columns(:posts)
        end

        pool.checkin connection
      end

      def test_concurrent_connection_establishment
        skip_fiber_testing
        assert_operator @pool.connections.size, :<=, 1

        all_threads_in_new_connection = Concurrent::CountDownLatch.new(@pool.size - @pool.connections.size)
        all_go                        = Concurrent::CountDownLatch.new

        @pool.singleton_class.class_eval do
          define_method(:new_connection) do
            all_threads_in_new_connection.count_down
            all_go.wait
            super()
          end
        end

        connecting_threads = []
        @pool.size.times do
          connecting_threads << new_thread { @pool.checkout }
        end

        begin
          Timeout.timeout(5) do
            # the kernel of the whole test is here, everything else is just scaffolding,
            # this latch will not be released unless conn. pool allows for concurrent
            # connection creation
            all_threads_in_new_connection.wait
          end
        rescue Timeout::Error
          flunk "pool unable to establish connections concurrently or implementation has " \
                "changed, this test then needs to patch a different :new_connection method"
        ensure
          # clean up the threads
          all_go.count_down
          connecting_threads.map(&:join)
        end
      end

      def test_checkout_queues_behind_maintenance_connections
        skip_fiber_testing

        pool = new_pool_with_options(max_connections: 3, reaping_frequency: nil, async: false)

        # Set up pool with 2 connections: one available, one checked out
        conn1 = pool.checkout
        conn2 = pool.checkout
        pool.checkin(conn1)

        maintenance_started = Concurrent::Event.new
        maintenance_continuing = Concurrent::Event.new
        checkout_complete = Concurrent::Event.new

        maintenance_thread = new_thread do
          n = 0

          pool.send(:sequential_maintenance, proc { true }) do |_|
            maintenance_started.set
            maintenance_continuing.wait

            n += 1
          end

          n
        end

        maintenance_started.wait

        checkout_thread = new_thread do
          conn = pool.checkout # blocks waiting for the in-maintenance connection

          checkout_complete.set
          pool.checkin(conn)
          conn
        end

        # Give the checkout attempt time to start blocking
        sleep 0.01

        # checkout_thread is now waiting; #checkout has not returned
        assert_equal 1, pool.num_waiting_in_queue
        assert_not checkout_complete.set?

        # Release maintenance, allowing checkout to occur
        maintenance_continuing.set

        # After checkout_thread is complete: confirm it got the connection we
        # were previously maintaining
        assert_equal conn1, checkout_thread.value

        # Correspondingly, no new third connection was created
        assert_equal 2, pool.connections.size

        # Maintenance only visited the available connection (and only once)
        assert_equal 1, maintenance_thread.value

        pool.checkin(conn2)
      end

      def test_non_bang_disconnect_and_clear_reloadable_connections_throw_exception_if_threads_dont_return_their_conns
        Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception
        @pool.checkout_timeout = 0.001 # no need to delay test suite by waiting the whole full default timeout
        [:disconnect, :clear_reloadable_connections].each do |group_action_method|
          @pool.with_connection do |connection|
            error = assert_raises(ExclusiveConnectionTimeoutError) do
              new_thread { @pool.public_send(group_action_method) }.join
            end
            assert_equal @pool, error.connection_pool
          end
        end
      ensure
        Thread.report_on_exception = original_report_on_exception
      end

      def test_disconnect_and_clear_reloadable_connections_attempt_to_wait_for_threads_to_return_their_conns
        skip_fiber_testing
        @pool.checkout_timeout = 1.0 # allow extra time for our thread to get stuck
        [:disconnect, :disconnect!, :clear_reloadable_connections, :clear_reloadable_connections!].each do |group_action_method|
          thread = timed_join_result = nil
          @pool.with_connection do |connection|
            thread = new_thread { @pool.send(group_action_method) }

            # give the other `thread` some time to get stuck in `group_action_method`
            timed_join_result = thread.join(0.3)
            # thread.join # => `nil` means the other thread hasn't finished running and is still waiting for us to
            # release our connection
            assert_nil timed_join_result

            # assert that since this is within default timeout our connection hasn't been forcefully taken away from us
            assert_predicate @pool, :active_connection?
          end
        ensure
          thread.join if thread && !timed_join_result # clean up the other thread
        end
      end

      def test_bang_versions_of_disconnect_and_clear_reloadable_connections_if_unable_to_acquire_all_connections_proceed_anyway
        @pool.checkout_timeout = 0.001 # no need to delay test suite by waiting the whole full default timeout

        @pool.with_connection do |connection|
          new_thread { @pool.disconnect! }.join
          # assert connection has been forcefully taken away from us
          assert_not_predicate @pool, :active_connection?

          # make a new connection for with_connection to clean up
          @pool.lease_connection
        end
        @pool.release_connection

        @pool.with_connection do |connection|
          new_thread { @pool.clear_reloadable_connections! }.join
          # assert connection has been forcefully taken away from us
          assert_not_predicate @pool, :active_connection?

          # make a new connection for with_connection to clean up
          @pool.lease_connection
        end
      end

      def test_disconnect_and_clear_reloadable_connections_are_able_to_preempt_other_waiting_threads
        skip_fiber_testing
        with_single_connection_pool(checkout_timeout: 1.0) do |pool|
          [:disconnect, :disconnect!, :clear_reloadable_connections, :clear_reloadable_connections!].each do |group_action_method|
            conn               = pool.lease_connection # drain the only available connection
            second_thread_done = Concurrent::Event.new

            begin
              # create a first_thread and let it get into the FIFO queue first
              first_thread = new_thread do
                pool.with_connection { second_thread_done.wait }
              end

              # wait for first_thread to get in queue
              pass_to(first_thread) until pool.num_waiting_in_queue == 1

              # create a different, later thread, that will attempt to do a "group action",
              # but because of the group action semantics it should be able to preempt the
              # first_thread when a connection is made available
              second_thread = new_thread do
                pool.send(group_action_method)
                second_thread_done.set
              end

              # wait for second_thread to get in queue
              pass_to(second_thread) until pool.num_waiting_in_queue == 2

              # return the only available connection
              pool.checkin(conn)

              # if the second_thread is not able to preempt the first_thread,
              # they will temporarily (until either of them timeouts with ConnectionTimeoutError)
              # deadlock and a join(2) timeout will be reached
              assert second_thread.join(2), "#{group_action_method} is not able to preempt other waiting threads"

            ensure
              # post test clean up
              failed = !second_thread_done.set?

              if failed
                second_thread_done.set

                first_thread&.join(2)
                second_thread&.join(2)
              end

              first_thread.join(10) || raise("first_thread got stuck")
              second_thread.join(10) || raise("second_thread got stuck")
            end
          end
        end
      end

      def test_clear_reloadable_connections_creates_new_connections_for_waiting_threads_if_necessary
        skip_fiber_testing
        with_single_connection_pool(checkout_timeout: 1.0) do |pool|
          conn = pool.lease_connection # drain the only available connection
          def conn.requires_reloading? # make sure it gets removed from the pool by clear_reloadable_connections
            true
          end

          stuck_thread = new_thread do
            pool.with_connection { }
          end

          # wait for stuck_thread to get in queue
          pass_to(stuck_thread) until pool.num_waiting_in_queue == 1

          pool.clear_reloadable_connections

          unless stuck_thread.join(2)
            flunk "clear_reloadable_connections must not let other connection waiting threads get stuck in queue"
          end

          assert_equal 0, pool.num_waiting_in_queue
        end
      end

      def test_connection_pool_stat
        Thread.report_on_exception, original_report_on_exception = false, Thread.report_on_exception
        with_single_connection_pool do |pool|
          pool.with_connection do |connection|
            stats = pool.stat
            assert_equal({ size: 1, connections: 1, busy: 1, dead: 0, idle: 0, waiting: 0, checkout_timeout: 0.2 }, stats)
          end

          stats = pool.stat
          assert_equal({ size: 1, connections: 1, busy: 0, dead: 0, idle: 1, waiting: 0, checkout_timeout: 0.2 }, stats)

          assert_raise(ThreadError) do
            new_thread do
              pool.checkout
              raise ThreadError
            end.join
          end

          stats = pool.stat
          assert_equal({ size: 1, connections: 1, busy: 0, dead: 1, idle: 0, waiting: 0, checkout_timeout: 0.2 }, stats)
        ensure
          Thread.report_on_exception = original_report_on_exception
        end
      end

      def test_public_connections_access_threadsafe
        _conn1 = @pool.checkout
        conn2 = @pool.checkout

        connections = @pool.connections
        found_conn = nil

        # Without assuming too much about implementation
        # details make sure that a concurrent change to
        # the pool is thread-safe.
        connections.each_index do |idx|
          if connections[idx] == conn2
            new_thread do
              @pool.remove(conn2)
            end.join
          end
          found_conn = connections[idx]
        end

        assert_not_nil found_conn
      end

      def test_role_and_shard_is_returned
        assert_equal :writing, @pool_config.role
        assert_equal :writing, @pool.role
        assert_equal :writing, @pool.lease_connection.role

        assert_equal :default, @pool_config.shard
        assert_equal :default, @pool.shard
        assert_equal :default, @pool.lease_connection.shard

        db_config = ActiveRecord::Base.connection_pool.db_config
        pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :reading, :shard_one)
        pool = ConnectionPool.new(pool_config)

        assert_equal :reading, pool_config.role
        assert_equal :reading, pool.role
        assert_equal :reading, pool.lease_connection.role

        assert_equal :shard_one, pool_config.shard
        assert_equal :shard_one, pool.shard
        assert_equal :shard_one, pool.lease_connection.shard
      ensure
        pool&.disconnect!
      end

      def test_pin_connection_always_returns_the_same_connection
        assert_not_predicate @pool, :active_connection?
        @pool.pin_connection!(true)
        pinned_connection = @pool.checkout

        assert_not_predicate @pool, :active_connection?
        assert_same pinned_connection, @pool.lease_connection
        assert_predicate @pool, :active_connection?

        assert_same pinned_connection, @pool.checkout

        @pool.release_connection
        assert_not_predicate @pool, :active_connection?
        assert_same pinned_connection, @pool.checkout
      end

      def test_pin_connection_connected?
        skip("Can't test with in-memory dbs") if in_memory_db?

        assert_not_predicate @pool, :connected?
        @pool.pin_connection!(true)
        assert_predicate @pool, :connected?

        pin_connection = @pool.checkout

        @pool.disconnect
        assert_not_predicate @pool, :connected?
        assert_same pin_connection, @pool.checkout
        assert_predicate @pool, :connected?
      end

      def test_pin_connection_synchronize_the_connection
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock
        @pool.pin_connection!(true)
        assert_not_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock
        @pool.unpin_connection!
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock

        @pool.pin_connection!(false)
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock
      end

      def test_pin_connection_opens_a_transaction
        assert_instance_of NullTransaction, @pool.lease_connection.current_transaction
        @pool.pin_connection!(true)
        assert_instance_of RealTransaction, @pool.lease_connection.current_transaction
        @pool.unpin_connection!
        assert_instance_of NullTransaction, @pool.lease_connection.current_transaction
      end

      def test_unpin_connection_returns_whether_transaction_has_been_rolledback
        @pool.pin_connection!(true)
        assert_equal true, @pool.unpin_connection!

        @pool.pin_connection!(true)
        @pool.lease_connection.commit_transaction
        assert_equal false, @pool.unpin_connection!

        @pool.pin_connection!(true)
        @pool.lease_connection.rollback_transaction
        assert_equal false, @pool.unpin_connection!
      end

      def test_pin_connection_nesting
        assert_instance_of NullTransaction, @pool.lease_connection.current_transaction
        @pool.pin_connection!(true)
        assert_instance_of RealTransaction, @pool.lease_connection.current_transaction
        @pool.pin_connection!(true)
        assert_instance_of SavepointTransaction, @pool.lease_connection.current_transaction
        @pool.unpin_connection!
        assert_instance_of RealTransaction, @pool.lease_connection.current_transaction
        @pool.unpin_connection!
        assert_instance_of NullTransaction, @pool.lease_connection.current_transaction

        assert_raises(RuntimeError, match: /There isn't a pinned connection/) do
          @pool.unpin_connection!
        end
      end

      def test_pin_connection_nesting_lock
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock

        @pool.pin_connection!(true)
        actual_lock = @pool.lease_connection.lock
        assert_not_equal ActiveSupport::Concurrency::NullLock, actual_lock

        @pool.pin_connection!(false)
        assert_same actual_lock, @pool.lease_connection.lock

        @pool.unpin_connection!
        assert_same actual_lock, @pool.lease_connection.lock

        @pool.unpin_connection!
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock
      end

      def test_pin_connection_nesting_lock_inverse
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock

        @pool.pin_connection!(false)
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock

        @pool.pin_connection!(true)
        actual_lock = @pool.lease_connection.lock
        assert_not_equal ActiveSupport::Concurrency::NullLock, actual_lock

        @pool.unpin_connection!
        assert_same actual_lock, @pool.lease_connection.lock # The lock persist until full unpin

        @pool.unpin_connection!
        assert_equal ActiveSupport::Concurrency::NullLock, @pool.lease_connection.lock
      end

      def test_inspect_does_not_show_secrets
        assert_match(/#<ActiveRecord::ConnectionAdapters::ConnectionPool env_name="\w+" role=:writing>/, @pool.inspect)

        db_config = ActiveRecord::Base.connection_pool.db_config
        pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :reading, :shard_one)
        pool = ConnectionPool.new(pool_config)

        assert_match(/#<ActiveRecord::ConnectionAdapters::ConnectionPool env_name="\w+" role=:reading shard=:shard_one>/, pool.inspect)
      ensure
        pool&.disconnect!
      end

      def test_checkout_callback_error_does_not_affect_permanent_lease_and_active_connection_state
        checkout_error = StandardError.new("error during checkout")
        proc_to_raise = -> { raise checkout_error }
        ActiveRecord::ConnectionAdapters::AbstractAdapter.set_callback(:checkout, :after, proc_to_raise)

        assert_predicate @pool, :permanent_lease?
        assert_not_predicate @pool, :active_connection?

        error = assert_raises StandardError do
          @pool.lease_connection
        end
        assert_same checkout_error, error

        assert_predicate @pool, :permanent_lease?
        assert_not_predicate @pool, :active_connection?
      ensure
        ActiveRecord::ConnectionAdapters::AbstractAdapter.skip_callback(:checkout, :after, proc_to_raise)
      end

      def test_unlimited_connections_with_nil
        pool = new_pool_with_options(max_connections: nil)

        assert_nil pool.max_connections
        assert_nil pool.size

        # Should be able to create many connections without hitting a limit
        connections = []
        10.times do
          connections << pool.checkout
        end

        assert_equal 10, connections.size
        connections.each { |conn| pool.checkin(conn) }
      ensure
        pool&.disconnect!
      end

      def test_unlimited_connections_with_negative_one
        pool = new_pool_with_options(max_connections: -1)

        assert_nil pool.max_connections
        assert_nil pool.size

        # Should be able to create many connections without hitting a limit
        connections = []
        10.times do
          connections << pool.checkout
        end

        assert_equal 10, connections.size
        connections.each { |conn| pool.checkin(conn) }
      ensure
        pool&.disconnect!
      end

      def test_zero_connections_means_zero_limit
        pool = new_pool_with_options(max_connections: 0)

        assert_equal 0, pool.max_connections
        assert_equal 0, pool.size

        # Should not be able to create any connections
        error = assert_raises(ActiveRecord::ConnectionTimeoutError) do
          pool.checkout
        end
        assert_match(/could not obtain a connection from the pool/, error.message)
      ensure
        pool&.disconnect!
      end

      def test_unlimited_connections_stat_reports_nil_size
        pool = new_pool_with_options(max_connections: nil)

        stat = pool.stat
        assert_nil stat[:size]
        assert_equal 0, stat[:connections]
        assert_equal 0, stat[:busy]
        assert_equal 0, stat[:idle]
      ensure
        pool&.disconnect!
      end

      private
        def active_connections(pool)
          pool.connections.find_all(&:in_use?)
        end

        def with_single_connection_pool(**options)
          config = @db_config.configuration_hash.merge(max_connections: 1, **options)
          db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new("arunit", "primary", config)
          pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :writing, :default)

          yield(pool = ConnectionPool.new(pool_config))
        ensure
          pool.disconnect! if pool
        end

        def new_pool_with_options(async: true, **options)
          config = @db_config.configuration_hash.merge(options)
          db_config = ActiveRecord::DatabaseConfigurations::HashConfig.new(@db_config.env_name, @db_config.name, config)
          pool_config = ActiveRecord::ConnectionAdapters::PoolConfig.new(ActiveRecord::Base, db_config, :writing, :default)
          pool = ConnectionPool.new(pool_config)
          pool.instance_variable_set(:@async_executor, nil) unless async
          @pools << pool
          pool
        end
    end

    class ConnectionPoolThreadTest < ActiveRecord::TestCase
      include ConnectionPoolTests

      class ThreadConnectionTestModel < ActiveRecord::Base
        self.abstract_class = true
      end

      def setup
        @previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level

        ActiveSupport::IsolatedExecutionState.isolation_level = :thread
        @connection_test_model_class = ThreadConnectionTestModel

        super
      end

      def teardown
        super
        ActiveSupport::IsolatedExecutionState.isolation_level = @previous_isolation_level
      end

      def test_lock_thread_allow_fiber_reentrency
        connection = @pool.checkout
        connection.lock_thread = ActiveSupport::IsolatedExecutionState.context
        connection.transaction do
          enumerator = Enumerator.new do |yielder|
            connection.transaction do
              yielder.yield 1
            end
          end
          assert_equal 1, enumerator.next
        end
      end

      private
        def new_thread(...)
          Thread.new(...)
        end

        def stop_thread
          Thread.stop
        end

        def pass_to(_thread)
          Thread.pass
        end

        def skip_fiber_testing; end
    end

    class ConnectionPoolFiberTest < ActiveRecord::TestCase
      include ConnectionPoolTests

      class FiberConnectionTestModel < ActiveRecord::Base
        self.abstract_class = true
      end

      class ThreadlikeFiber < Fiber
        def join(timeout = nil)
          now = Time.now
          resume while alive? && (!timeout || Time.now - now < timeout)
        end

        def terminate
          nil
        end

        unless method_defined?(:kill) # RUBY_VERSION <= "3.3"
          def kill
          end
        end
      end

      def setup
        @previous_isolation_level = ActiveSupport::IsolatedExecutionState.isolation_level

        ActiveSupport::IsolatedExecutionState.isolation_level = :fiber
        @connection_test_model_class = FiberConnectionTestModel

        super
      end

      def teardown
        super
        ActiveSupport::IsolatedExecutionState.isolation_level = @previous_isolation_level
      end

      private
        def new_thread(*args, &block)
          ThreadlikeFiber.new(*args, &block)
        end

        def stop_thread
          Fiber.yield
        end

        def pass_to(fiber)
          fiber.resume
        end

        def skip_fiber_testing
          skip "Can't test isolation_level=fiber without a Ruby 3.1+ Fiber Scheduler"
        end
    end
  end
end
