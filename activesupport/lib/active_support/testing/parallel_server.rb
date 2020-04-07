# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      class Server
        include DRb::DRbUndumped

        def initialize
          @queue = Queue.new
        end

        def record(reporter, result)
          raise DRb::DRbConnError if result.is_a?(DRb::DRbUnknown)

          reporter.synchronize do
            reporter.record(result)
          end
        end

        def <<(o)
          o[2] = DRbObject.new(o[2]) if o
          @queue << o
        end

        def length
          @queue.length
        end

        def pop; @queue.pop; end
      end
    end
  end
end
