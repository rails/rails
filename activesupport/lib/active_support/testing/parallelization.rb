# frozen_string_literal: true

require "drb"
require "drb/unix"

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      class Server
        include DRb::DRbUndumped

        def initialize
          @queue = Queue.new
        end

        def record(reporter, result)
          reporter.synchronize do
            reporter.record(result)
          end
        end

        def <<(o)
          @queue << o
        end

        def pop; @queue.pop; end
      end

      @@after_fork_hooks = []

      def self.after_fork_hook(&blk)
        @@after_fork_hooks << blk
      end

      cattr_reader :after_fork_hooks

      @@run_cleanup_hooks = []

      def self.run_cleanup_hook(&blk)
        @@run_cleanup_hooks << blk
      end

      cattr_reader :run_cleanup_hooks

      def initialize(queue_size)
        @queue_size = queue_size
        @queue      = Server.new
        @pool       = []

        @url = DRb.start_service("drbunix:", @queue).uri
      end

      def after_fork(worker)
        self.class.after_fork_hooks.each do |cb|
          cb.call(worker)
        end
      end

      def run_cleanup(worker)
        self.class.run_cleanup_hooks.each do |cb|
          cb.call(worker)
        end
      end

      def start
        @pool = @queue_size.times.map do |worker|
          fork do
            begin
              DRb.stop_service

              after_fork(worker)

              queue = DRbObject.new_with_uri(@url)

              while job = queue.pop
                klass    = job[0]
                method   = job[1]
                reporter = job[2]
                result   = Minitest.run_one_method(klass, method)

                begin
                  queue.record(reporter, result)
                rescue DRb::DRbConnError
                  result.failures.each do |failure|
                    failure.exception = DRb::DRbRemoteError.new(failure.exception)
                  end
                  queue.record(reporter, result)
                end
              end
            ensure
              run_cleanup(worker)
            end
          end
        end
      end

      def <<(work)
        @queue << work
      end

      def shutdown
        @queue_size.times { @queue << nil }
        @pool.each { |pid| Process.waitpid pid }
      end
    end
  end
end
