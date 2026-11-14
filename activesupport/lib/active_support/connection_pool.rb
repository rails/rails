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

require "timeout"

module ActiveSupport
  class ConnectionPool # :nodoc:
    class Error < ::RuntimeError # :nodoc:
    end

    class PoolShuttingDownError < ActiveSupport::ConnectionPool::Error # :nodoc:
    end

    class TimeoutError < ::Timeout::Error # :nodoc:
    end
  end

  # Generic connection pool class for sharing a limited number of objects or network connections
  # among many threads.  Note: pool elements are lazily created.
  #
  # Example usage with block (faster):
  #
  #    @pool = ConnectionPool.new { Redis.new }
  #    @pool.with do |redis|
  #      redis.lpop('my-list') if redis.llen('my-list') > 0
  #    end
  #
  # Using optional timeout override (for that single invocation)
  #
  #    @pool.with(timeout: 2.0) do |redis|
  #      redis.lpop('my-list') if redis.llen('my-list') > 0
  #    end
  #
  # Accepts the following options:
  # - :size - number of connections to pool, defaults to 5
  # - :timeout - amount of time to wait for a connection if none currently available, defaults to 5 seconds
  # - :auto_reload_after_fork - automatically drop all connections after fork, defaults to true
  #
  class ConnectionPool # :nodoc:
    attr_reader :size

    def initialize(timeout: 5, size: 5, auto_reload_after_fork: true, &block)
      raise ArgumentError, "Connection pool requires a block" unless block_given?

      @size = Integer(size)
      raise ArgumentError, "Connection pool size cannot be negative" if @size.negative?

      @timeout = Float(timeout)
      @available = TimedStack.new(size: @size, &block)
      @key = :"pool-#{@available.object_id}"
      @key_count = :"pool-#{@available.object_id}-count"
      @key_kwargs = :"pool-#{@available.object_id}-kwargs"
      INSTANCES[self] = self if auto_reload_after_fork && INSTANCES
    end

    def with(**kwargs)
      # We need to manage exception handling manually here in order
      # to work correctly with `Timeout.timeout` and `Thread#raise`.
      # Otherwise an interrupted Thread can leak connections.
      Thread.handle_interrupt(Exception => :never) do
        conn = checkout(**kwargs)
        begin
          Thread.handle_interrupt(Exception => :immediate) do
            yield conn
          end
        ensure
          checkin
        end
      end
    end
    alias_method :then, :with

    def checkout(timeout: @timeout, **kwargs)
      if ::Thread.current[@key]
        ::Thread.current[@key_count] += 1
        ::Thread.current[@key]
      else
        conn = @available.pop(timeout:, **kwargs)
        ::Thread.current[@key] = conn
        ::Thread.current[@key_count] = 1
        ::Thread.current[@key_kwargs] = kwargs
        conn
      end
    end

    def checkin(force: false)
      if ::Thread.current[@key]
        if ::Thread.current[@key_count] == 1 || force
          begin
            @available.push(::Thread.current[@key], **::Thread.current[@key_kwargs])
          ensure
            ::Thread.current[@key] = nil
            ::Thread.current[@key_count] = nil
            ::Thread.current[@key_kwargs] = nil
          end
        else
          ::Thread.current[@key_count] -= 1
        end
      elsif !force
        raise ConnectionPool::Error, "no connections are checked out"
      end

      nil
    end

    ##
    # Shuts down the ConnectionPool by passing each connection to +block+ and
    # then removing it from the pool. Attempting to checkout a connection after
    # shutdown will raise +ConnectionPool::PoolShuttingDownError+.
    def shutdown(&block)
      @available.shutdown(&block)
    end

    ##
    # Reloads the ConnectionPool by passing each connection to +block+ and then
    # removing it the pool. Subsequent checkouts will create new connections as
    # needed.
    def reload(&block)
      @available.shutdown(reload: true, &block)
    end

    ## Reaps idle connections that have been idle for over +idle_seconds+.
    # +idle_seconds+ defaults to 60.
    def reap(idle_seconds: 60, &block)
      @available.reap(idle_seconds:, &block)
    end

    # Number of pool entries available for checkout at this instant.
    def available
      @available.length
    end

    # Number of pool entries created and idle in the pool.
    def idle
      @available.idle
    end
  end
end

require_relative "connection_pool/timed_stack"
require_relative "connection_pool/fork"
