require 'concurrent/atomic/count_down_latch'

module ActiveSupport
  module Concurrency
    class Latch < Concurrent::CountDownLatch

      def initialize(count = 1)
        ActiveSupport::Deprecation.warn("ActiveSupport::Concurrency::Latch is deprecated. Please use Concurrent::CountDownLatch instead.")
        super(count)
      end

      alias_method :release, :count_down

      def await
        wait(nil)
      end
    end
  end
end
