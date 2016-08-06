require "concurrent/atomic/count_down_latch"

module ActiveSupport
  module Concurrency
    class Latch
      def initialize(count = 1)
        if count == 1
          ActiveSupport::Deprecation.warn("ActiveSupport::Concurrency::Latch is deprecated. Please use Concurrent::Event instead.")
        else
          ActiveSupport::Deprecation.warn("ActiveSupport::Concurrency::Latch is deprecated. Please use Concurrent::CountDownLatch instead.")
        end

        @inner = Concurrent::CountDownLatch.new(count)
      end

      def release
        @inner.count_down
      end

      def await
        @inner.wait(nil)
      end
    end
  end
end
