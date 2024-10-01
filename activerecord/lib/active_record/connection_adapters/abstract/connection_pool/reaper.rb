# frozen_string_literal: true

require "weakref"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      # = Active Record Connection Pool \Reaper
      #
      # The reaper is a singleton that exists in the background of the process
      # and is responsible for general maintenance of all the connection pools.
      #
      # It will reclaim connections that are leased to now-dead threads,
      # ensuring that a bad thread can't leak a pool slot forever. By definition,
      # this involves touching currently-leased connections, but that is safe
      # because the owning thread is known to be dead.
      #
      # Beyond that, it manages the health of available / unleased connections:
      #  * retiring connections that have been idle[1] for too long
      #  * creating occasional activity on inactive[1] connections
      #  * keeping the pool prepopulated up to its minimum size
      #  * proactively connecting to the target database from any pooled
      #    connections that had lazily deferred that step
      #  * resetting or replacing connections that are known to be broken
      #
      #
      # [1]: "idle" and "inactive" here distinguish between connections that
      # have not been requested by the application in a while (idle) and those
      # that have not spoken to their remote server in a while (inactive). The
      # former is a desirable opportunity to reduce our connection count
      # (`idle_timeout`); the latter is a risk that the server or a firewall may
      # drop a connection we still anticipate using (avoided by `keepalive`).
      class Reaper
        attr_reader :pool, :frequency

        def initialize(pool, frequency)
          @pool      = pool
          @frequency = frequency
        end

        @mutex = Mutex.new
        @pools = {}
        @threads = {}

        class << self
          def register_pool(pool, frequency) # :nodoc:
            @mutex.synchronize do
              unless @threads[frequency]&.alive?
                @threads[frequency] = spawn_thread(frequency)
              end
              @pools[frequency] ||= []
              @pools[frequency] << WeakRef.new(pool)
            end
          end

          private
            def spawn_thread(frequency)
              Thread.new(frequency) do |t|
                # Advise multi-threaded app servers to ignore this thread for
                # the purposes of fork safety warnings
                Thread.current.thread_variable_set(:fork_safe, true)
                Thread.current.name = "AR Pool Reaper"
                running = true
                while running
                  sleep t
                  @mutex.synchronize do
                    @pools[frequency].select! do |pool|
                      pool.weakref_alive? && !pool.discarded?
                    end

                    @pools[frequency].each do |ref|
                      p = ref.__getobj__

                      p.reap
                      p.flush
                      p.prepopulate
                      p.retire_old_connections
                      p.keep_alive
                      p.preconnect
                    rescue WeakRef::RefError
                    end

                    if @pools[frequency].empty?
                      @pools.delete(frequency)
                      @threads.delete(frequency)
                      running = false
                    end
                  end
                end
              end
            end
        end

        def run
          return unless frequency && frequency > 0
          self.class.register_pool(pool, frequency)
        end
      end
    end
  end
end
