# :markup: markdown
# frozen_string_literal: true

#
# Source: connection_pool 5a3d762481b9ec46b7cfdf643f8597bd3fc5f02d, https://github.com/mperham/connection_pool/tree/main
#
# Copyright (c) 2011 Mike Perham
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

module ActiveSupport
  class ConnectionPool # :nodoc:
    ##
    # The TimedStack manages a pool of homogeneous connections (or any resource
    # you wish to manage). Connections are created lazily up to a given maximum
    # number.
    #
    # Examples:
    #
    #    ts = TimedStack.new(size: 1) { MyConnection.new }
    #
    #    # fetch a connection
    #    conn = ts.pop
    #
    #    # return a connection
    #    ts.push conn
    #
    #    conn = ts.pop
    #    ts.pop timeout: 5
    #    #=> raises ConnectionPool::TimeoutError after 5 seconds
    class TimedStack # :nodoc:
      attr_reader :max

      ##
      # Creates a new pool with +size+ connections that are created from the given
      # +block+.
      def initialize(size: 0, &block)
        @create_block = block
        @created = 0
        @que = []
        @max = size
        @mutex = Thread::Mutex.new
        @resource = Thread::ConditionVariable.new
        @shutdown_block = nil
      end

      ##
      # Returns +obj+ to the stack. Additional kwargs are ignored in TimedStack but may be
      # used by subclasses that extend TimedStack.
      def push(obj, **kwargs)
        @mutex.synchronize do
          if @shutdown_block
            @created -= 1 unless @created == 0
            @shutdown_block.call(obj)
          else
            store_connection obj, **kwargs
          end

          @resource.broadcast
        end
      end
      alias_method :<<, :push

      ##
      # Retrieves a connection from the stack. If a connection is available it is
      # immediately returned. If no connection is available within the given
      # timeout a ConnectionPool::TimeoutError is raised.
      #
      # @option options [Float] :timeout (0.5) Wait this many seconds for an available entry
      # @option options [Class] :exception (ConnectionPool::TimeoutError) Exception class to raise
      #   if an entry was not available within the timeout period. Use `exception: false` to return nil.
      #
      # Other options may be used by subclasses that extend TimedStack.
      def pop(timeout: 0.5, exception: ConnectionPool::TimeoutError, **kwargs)
        deadline = current_time + timeout
        @mutex.synchronize do
          loop do
            raise ConnectionPool::PoolShuttingDownError if @shutdown_block
            if (conn = try_fetch_connection(**kwargs))
              return conn
            end

            connection = try_create(**kwargs)
            return connection if connection

            to_wait = deadline - current_time
            if to_wait <= 0
              if exception
                raise exception, "Waited #{timeout} sec, #{length}/#{@max} available"
              else
                return nil
              end
            end
            @resource.wait(@mutex, to_wait)
          end
        end
      end

      ##
      # Shuts down the TimedStack by passing each connection to +block+ and then
      # removing it from the pool. Attempting to checkout a connection after
      # shutdown will raise +ConnectionPool::PoolShuttingDownError+ unless
      # +:reload+ is +true+.
      def shutdown(reload: false, &block)
        raise ArgumentError, "shutdown must receive a block" unless block

        @mutex.synchronize do
          @shutdown_block = block
          @resource.broadcast

          shutdown_connections
          @shutdown_block = nil if reload
        end
      end

      ##
      # Reaps connections that were checked in more than +idle_seconds+ ago.
      def reap(idle_seconds:)
        raise ArgumentError, "reap must receive a block" unless block_given?
        raise ArgumentError, "idle_seconds must be a number" unless idle_seconds.is_a?(Numeric)
        raise ConnectionPool::PoolShuttingDownError if @shutdown_block

        count = idle
        count.times do
          conn = @mutex.synchronize do
            raise ConnectionPool::PoolShuttingDownError if @shutdown_block
            reserve_idle_connection(idle_seconds)
          end
          break unless conn

          yield conn
        end
      end

      ##
      # Returns +true+ if there are no available connections.
      def empty?
        (@created - @que.length) >= @max
      end

      ##
      # The number of connections available on the stack.
      def length
        @max - @created + @que.length
      end

      ##
      # The number of connections created and available on the stack.
      def idle
        @que.length
      end

      private
        def current_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must returns a connection from the stack if one exists. Allows
        # subclasses with expensive match/search algorithms to avoid double-handling
        # their stack.
        def try_fetch_connection(**kwargs)
          connection_stored?(**kwargs) && fetch_connection(**kwargs)
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must returns true if a connection is available on the stack.
        def connection_stored?(**_kwargs)
          !@que.empty?
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must return a connection from the stack.
        def fetch_connection(**_kwargs)
          @que.pop&.first
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must shut down all connections on the stack.
        def shutdown_connections(**kwargs)
          while (conn = try_fetch_connection(**kwargs))
            @created -= 1 unless @created == 0
            @shutdown_block.call(conn)
          end
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method returns the oldest idle connection if it has been idle for more than idle_seconds.
        def reserve_idle_connection(idle_seconds)
          return unless idle_connections?(idle_seconds)

          @created -= 1 unless @created == 0

          # Most active elements are at the tail of the array.
          # Most idle will be at the head so `shift` rather than `pop`.
          @que.shift.first
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # Returns true if the first connection in the stack has been idle for more than idle_seconds
        def idle_connections?(idle_seconds)
          return unless connection_stored?
          # Most idle will be at the head so `first`
          age = (current_time - @que.first.last)
          age > idle_seconds
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must return +obj+ to the stack.
        def store_connection(obj, **_kwargs)
          @que.push [obj, current_time]
        end

        ##
        # This is an extension point for TimedStack and is called with a mutex.
        #
        # This method must create a connection if and only if the total number of
        # connections allowed has not been met.
        def try_create(**_kwargs)
          unless @created == @max
            object = @create_block.call
            @created += 1
            object
          end
        end
    end
  end
end
