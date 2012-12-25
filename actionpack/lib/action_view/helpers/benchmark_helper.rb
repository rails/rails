require 'active_support/benchmarkable'

module ActionView
  module Helpers
    module BenchmarkHelper #:nodoc:
      include ActiveSupport::Benchmarkable

      def benchmark(*)
        capture { super }
      end
    end
  end
end
