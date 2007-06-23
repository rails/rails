require 'benchmark'

module ActionView
  module Helpers
    # This helper offers a method to measure the execution time of a block 
    # in a template.
    module BenchmarkHelper
      # Allows you to measure the execution time of a block 
      # in a template and records the result to the log. Wrap this block around
      # expensive operations or possible bottlenecks to get a time reading
      # for the operation.  For example, let's say you thought your file 
      # processing method was taking too long; you could wrap it in a benchmark block.
      #
      #  <% benchmark "Process data files" do %>
      #    <%= expensive_files_operation %>
      #  <% end %>
      #
      # That would add something like "Process data files (0.34523)" to the log,
      # which you can then use to compare timings when optimizing your code.
      #
      # You may give an optional logger level as the second argument
      # (:debug, :info, :warn, :error); the default value is :info.
      def benchmark(message = "Benchmarking", level = :info)
        if @logger
          real = Benchmark.realtime { yield }
          @logger.send level, "#{message} (#{'%.5f' % real})"
        end
      end
    end
  end
end
