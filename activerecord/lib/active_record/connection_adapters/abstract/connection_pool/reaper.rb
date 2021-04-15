# frozen_string_literal: true

require "thread"
require "weakref"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionPool
      # Every +frequency+ seconds, the reaper will call +reap+ and +flush+ on
      # +pool+. A reaper instantiated with a zero frequency will never reap
      # the connection pool.
      #
      # Configure the frequency by setting +reaping_frequency+ in your database
      # yaml file (default 60 seconds).
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
                running = true
                while running
                  sleep t
                  @mutex.synchronize do
                    @pools[frequency].select! do |pool|
                      pool.weakref_alive? && !pool.discarded?
                    end

                    @pools[frequency].each do |p|
                      p.reap
                      p.flush
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
