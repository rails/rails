require "cases/helper"
require "concurrent/atomic/count_down_latch"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPoolTest < ActiveRecord::TestCase
      attr_reader :pool

      def setup
        super

        # Keep a duplicate pool so we do not bother others
        @pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec

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

      teardown do
        @pool.disconnect!
      end

      def active_connections(pool)
        pool.connections.find_all(&:in_use?)
      end

      def test_checkout_after_close
        connection = pool.connection
        assert connection.in_use?

        connection.close
        assert !connection.in_use?

        assert pool.connection.in_use?
      end

      def test_released_connection_moves_between_threads
        thread_conn = nil

        Thread.new {
          pool.with_connection do |conn|
            thread_conn = conn
          end
        }.join

        assert thread_conn

        Thread.new {
          pool.with_connection do |conn|
            assert_equal thread_conn, conn
          end
        }.join
      end

      def test_with_connection
        assert_equal 0, active_connections(pool).size

        main_thread = pool.connection
        assert_equal 1, active_connections(pool).size

        Thread.new {
          pool.with_connection do |conn|
            assert conn
            assert_equal 2, active_connections(pool).size
          end
          assert_equal 1, active_connections(pool).size
        }.join

        main_thread.close
        assert_equal 0, active_connections(pool).size
      end

      def test_active_connection_in_use
        assert !pool.active_connection?
        main_thread = pool.connection

        assert pool.active_connection?

        main_thread.close

        assert !pool.active_connection?
      end

      def test_full_pool_exception
        @pool.size.times { @pool.checkout }
        assert_raises(ConnectionTimeoutError) do
          @pool.checkout
        end
      end

      def test_full_pool_blocks
        cs = @pool.size.times.map { @pool.checkout }
        t = Thread.new { @pool.checkout }

        # make sure our thread is in the timeout section
        Thread.pass until @pool.num_waiting_in_queue == 1

        connection = cs.first
        connection.close
        assert_equal connection, t.join.value
      end

      def test_removing_releases_latch
        cs = @pool.size.times.map { @pool.checkout }
        t = Thread.new { @pool.checkout }

        # make sure our thread is in the timeout section
        Thread.pass until @pool.num_waiting_in_queue == 1

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
        child = Thread.new do
          @pool.checkout
          @pool.checkout
          ready.count_down
          Thread.stop
        end
        ready.wait

        assert_equal 3, active_connections(@pool).size

        child.terminate
        child.join
        @pool.reap

        assert_equal 1, active_connections(@pool).size
      ensure
        @pool.connections.each { |conn| conn.close if conn.in_use? }
      end

      def test_remove_connection
        conn = @pool.checkout
        assert conn.in_use?

        length = @pool.connections.length
        @pool.remove conn
        assert conn.in_use?
        assert_equal(length - 1, @pool.connections.length)
      ensure
        conn.close
      end

      def test_remove_connection_for_thread
        conn = @pool.connection
        @pool.remove conn
        assert_not_equal(conn, @pool.connection)
      ensure
        conn.close if conn
      end

      def test_active_connection?
        assert !@pool.active_connection?
        assert @pool.connection
        assert @pool.active_connection?
        @pool.release_connection
        assert !@pool.active_connection?
      end

      def test_checkout_behaviour
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
        connection = pool.connection
        assert_not_nil connection
        threads = []
        4.times do |i|
          threads << Thread.new(i) do
            connection = pool.connection
            assert_not_nil connection
            connection.close
          end
        end

        threads.each(&:join)

        Thread.new do
          assert pool.connection
          pool.connection.close
        end.join
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
        @pool.instance_variable_set(:@size, 10)
        expected = (1..@pool.size).to_a.freeze
        # check out all connections so our threads start out waiting
        conns = expected.map { @pool.checkout }
        mutex = Mutex.new
        order = []
        errors = []

        threads = expected.map do |i|
          t = Thread.new {
            begin
              @pool.checkout # never checked back in
              mutex.synchronize { order << i }
            rescue => e
              mutex.synchronize { errors << e }
            end
          }
          Thread.pass until @pool.num_waiting_in_queue == i
          t
        end

        # this should wake up the waiting threads one by one in order
        conns.each { |conn| @pool.checkin(conn); sleep 0.1 }

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
        @pool.instance_variable_set(:@size, 10)
        # take all the connections
        conns = (1..10).map { @pool.checkout }
        mutex = Mutex.new
        successes = []    # threads that successfully got a connection
        errors = []

        make_thread = proc do |i|
          t = Thread.new {
            begin
              @pool.checkout # never checked back in
              mutex.synchronize { successes << i }
            rescue => e
              mutex.synchronize { errors << e }
            end
          }
          Thread.pass until @pool.num_waiting_in_queue == i
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

        group1.each(&:join)
        group2.each(&:join)

        assert_equal((1..group1.size).to_a, winners.sort)

        if errors.any?
          raise errors.first
        end
      end

      def test_automatic_reconnect=
        pool = ConnectionPool.new ActiveRecord::Base.connection_pool.spec
        assert pool.automatic_reconnect
        assert pool.connection

        pool.disconnect!
        assert pool.connection

        pool.disconnect!
        pool.automatic_reconnect = false

        assert_raises(ConnectionNotEstablished) do
          pool.connection
        end

        assert_raises(ConnectionNotEstablished) do
          pool.with_connection
        end
      end

      def test_pool_sets_connection_visitor
        assert @pool.connection.visitor.is_a?(Arel::Visitors::ToSql)
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
        ActiveRecord::Base.establish_connection :arunit
        assert_equal [:config, :connection_id, :spec_name], payloads[0].keys.sort
        assert_equal "primary", payloads[0][:spec_name]
      ensure
        ActiveSupport::Notifications.unsubscribe(subscription) if subscription
      end

      def test_pool_sets_connection_schema_cache
        connection = pool.checkout
        schema_cache = SchemaCache.new connection
        schema_cache.add(:posts)
        pool.schema_cache = schema_cache

        pool.with_connection do |conn|
          assert_not_same pool.schema_cache, conn.schema_cache
          assert_equal pool.schema_cache.size, conn.schema_cache.size
          assert_same pool.schema_cache.columns(:posts), conn.schema_cache.columns(:posts)
        end

        pool.checkin connection
      end

      def test_concurrent_connection_establishment
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
          connecting_threads << Thread.new { @pool.checkout }
        end

        begin
          Timeout.timeout(5) do
            # the kernel of the whole test is here, everything else is just scaffolding,
            # this latch will not be released unless conn. pool allows for concurrent
            # connection creation
            all_threads_in_new_connection.wait
          end
        rescue Timeout::Error
          flunk "pool unable to establish connections concurrently or implementation has " <<
                "changed, this test then needs to patch a different :new_connection method"
        ensure
          # clean up the threads
          all_go.count_down
          connecting_threads.map(&:join)
        end
      end

      def test_non_bang_disconnect_and_clear_reloadable_connections_throw_exception_if_threads_dont_return_their_conns
        @pool.checkout_timeout = 0.001 # no need to delay test suite by waiting the whole full default timeout
        [:disconnect, :clear_reloadable_connections].each do |group_action_method|
          @pool.with_connection do |connection|
            assert_raises(ExclusiveConnectionTimeoutError) do
              Thread.new { @pool.send(group_action_method) }.join
            end
          end
        end
      end

      def test_disconnect_and_clear_reloadable_connections_attempt_to_wait_for_threads_to_return_their_conns
        [:disconnect, :disconnect!, :clear_reloadable_connections, :clear_reloadable_connections!].each do |group_action_method|
          begin
            thread = timed_join_result = nil
            @pool.with_connection do |connection|
              thread = Thread.new { @pool.send(group_action_method) }

              # give the other `thread` some time to get stuck in `group_action_method`
              timed_join_result = thread.join(0.3)
              # thread.join # => `nil` means the other thread hasn't finished running and is still waiting for us to
              # release our connection
              assert_nil timed_join_result

              # assert that since this is within default timeout our connection hasn't been forcefully taken away from us
              assert @pool.active_connection?
            end
          ensure
            thread.join if thread && !timed_join_result # clean up the other thread
          end
        end
      end

      def test_bang_versions_of_disconnect_and_clear_reloadable_connections_if_unable_to_aquire_all_connections_proceed_anyway
        @pool.checkout_timeout = 0.001 # no need to delay test suite by waiting the whole full default timeout
        [:disconnect!, :clear_reloadable_connections!].each do |group_action_method|
          @pool.with_connection do |connection|
            Thread.new { @pool.send(group_action_method) }.join
            # assert connection has been forcefully taken away from us
            assert_not @pool.active_connection?

            # make a new connection for with_connection to clean up
            @pool.connection
          end
        end
      end

      def test_disconnect_and_clear_reloadable_connections_are_able_to_preempt_other_waiting_threads
        with_single_connection_pool do |pool|
          [:disconnect, :disconnect!, :clear_reloadable_connections, :clear_reloadable_connections!].each do |group_action_method|
            conn               = pool.connection # drain the only available connection
            second_thread_done = Concurrent::CountDownLatch.new

            # create a first_thread and let it get into the FIFO queue first
            first_thread = Thread.new do
              pool.with_connection { second_thread_done.wait }
            end

            # wait for first_thread to get in queue
            Thread.pass until pool.num_waiting_in_queue == 1

            # create a different, later thread, that will attempt to do a "group action",
            # but because of the group action semantics it should be able to preempt the
            # first_thread when a connection is made available
            second_thread = Thread.new do
              pool.send(group_action_method)
              second_thread_done.count_down
            end

            # wait for second_thread to get in queue
            Thread.pass until pool.num_waiting_in_queue == 2

            # return the only available connection
            pool.checkin(conn)

            # if the second_thread is not able to preempt the first_thread,
            # they will temporarily (until either of them timeouts with ConnectionTimeoutError)
            # deadlock and a join(2) timeout will be reached
            failed = true unless second_thread.join(2)

            #--- post test clean up start
            second_thread_done.count_down if failed

            # after `pool.disconnect()` the first thread will be left stuck in queue, no need to wait for
            # it to timeout with ConnectionTimeoutError
            if (group_action_method == :disconnect || group_action_method == :disconnect!) && pool.num_waiting_in_queue > 0
              pool.with_connection {} # create a new connection in case there are threads still stuck in a queue
            end

            first_thread.join
            second_thread.join
            #--- post test clean up end

            flunk "#{group_action_method} is not able to preempt other waiting threads" if failed
          end
        end
      end

      def test_clear_reloadable_connections_creates_new_connections_for_waiting_threads_if_necessary
        with_single_connection_pool do |pool|
          conn = pool.connection # drain the only available connection
          def conn.requires_reloading? # make sure it gets removed from the pool by clear_reloadable_connections
            true
          end

          stuck_thread = Thread.new do
            pool.with_connection {}
          end

          # wait for stuck_thread to get in queue
          Thread.pass until pool.num_waiting_in_queue == 1

          pool.clear_reloadable_connections

          unless stuck_thread.join(2)
            flunk "clear_reloadable_connections must not let other connection waiting threads get stuck in queue"
          end

          assert_equal 0, pool.num_waiting_in_queue
        end
      end

      private
      def with_single_connection_pool
        one_conn_spec = ActiveRecord::Base.connection_pool.spec.dup
        one_conn_spec.config[:pool] = 1 # this is safe to do, because .dupped ConnectionSpecification also auto-dups its config
        yield(pool = ConnectionPool.new(one_conn_spec))
      ensure
        pool.disconnect! if pool
      end
    end
  end
end
