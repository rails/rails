require 'benchmark'

module ActionView
  module Helpers
    module BenchmarkHelper
      # Measures the execution time of a block in a template and reports the result to the log. Example:
      #
      #  <% benchmark "Notes section" do %>
      #    <%= expensive_notes_operation %>
      #  <% end %>
      #
      # Will add something like "Notes section (0.345234)" to the log.
      def benchmark(message = "Benchmarking", &block)
        return if @logger.nil?

        bm = Benchmark.measure do
          block.call
        end
        
        @logger.info("#{message} (#{bm.real})")
      end
    end
  end
end