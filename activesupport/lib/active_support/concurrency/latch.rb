require 'thread'
require 'monitor'

module ActiveSupport
  module Concurrency
    class Latch
      def initialize(count = 1)
        @count = count
        @lock = Monitor.new
        @cv = @lock.new_cond
      end

      def release
        @lock.synchronize do
          @count -= 1 if @count > 0
          @cv.broadcast if @count.zero?
        end
      end

      def await
        @lock.synchronize do
          @cv.wait_while { @count > 0 }
        end
      end
    end
  end
end
