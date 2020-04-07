# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?
require "active_support/core_ext/module/attribute_accessors"
require "active_support/testing/parallel_server"
require "active_support/testing/parallel_worker"

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      def initialize(worker_count)
        @worker_count = worker_count
        @queue      = Server.new
        @pool       = []

        @url = DRb.start_service("drbunix:", @queue).uri
      end

      def start
        @pool = @worker_count.times.map do |worker|
          Worker.new(worker, @url).start
        end
      end

      def <<(work)
        @queue << work
      end

      def shutdown
        @worker_count.times { @queue << nil }
        @pool.each { |pid| Process.waitpid pid }

        if @queue.length > 0
          raise "Queue not empty, but all workers have finished. This probably means that a worker crashed and #{@queue.length} tests were missed."
        end
      end
    end
  end
end
