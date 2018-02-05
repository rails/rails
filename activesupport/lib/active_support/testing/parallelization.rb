# frozen_string_literal: true

require "drb"
require "drb/unix"
require "tempfile"

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

        def << o; @queue << o; end

        def pop; @queue.pop; end
      end

      @after_fork_hooks = []

      def self.after_fork_hook(&blk)
        @after_fork_hooks << blk
      end

      def self.after_fork_hooks
        @after_fork_hooks
      end

      @run_cleanup_hooks = []

      def self.run_cleanup_hook(&blk)
        @run_cleanup_hooks << blk
      end

      def self.run_cleanup_hooks
        @run_cleanup_hooks
      end

      def initialize(queue_size)
        @queue_size = queue_size
        @queue      = Server.new
        @url        = "drbunix://#{file}"
        @pool       = []

        DRb.start_service(@url, @queue)
      end

      def file
        File.join(Dir.tmpdir, tmpname)
      end

      def tmpname
        time = Time.now.strftime("%Y%m%d")
        "tests-#{time}-#{$$}-#{rand(0x100000000).to_s(36)}-fd"
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
            DRb.stop_service

            after_fork(worker)

            queue = DRbObject.new_with_uri(@url)

            while job = queue.pop
              klass    = job[0]
              method   = job[1]
              reporter = job[2]
              result   = Minitest.run_one_method(klass, method)

              queue.record(reporter, result)
            end

            run_cleanup(worker)
          end
        end
      end

      def << work
        @queue << work
      end

      def shutdown
        @queue_size.times { @queue << nil }
        @pool.each { |pid| Process.waitpid pid }
      end
    end
  end
end
