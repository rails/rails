# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?
require "active_support/core_ext/module/attribute_accessors"
require "active_support/testing/parallelization/test_distributor"
require "active_support/testing/parallelization/thread_pool_executor"
require "active_support/testing/parallelization/server"
require "active_support/testing/parallelization/worker"

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      @@before_fork_hooks = []

      def self.before_fork_hook(&blk)
        @@before_fork_hooks << blk
      end

      cattr_reader :before_fork_hooks

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

      def initialize(worker_count, work_stealing: false)
        @worker_count = worker_count

        distributor = (work_stealing ? RoundRobinWorkStealingDistributor : RoundRobinDistributor).new \
          worker_count: worker_count

        @queue_server = Server.new(distributor: distributor)
        @worker_pool = []
        @url = DRb.start_service("drbunix:", @queue_server).uri
      end

      def before_fork
        Parallelization.before_fork_hooks.each(&:call)
      end

      def start
        before_fork
        @worker_pool = @worker_count.times.map do |worker|
          Worker.new(worker, @url).start
        end
      end

      def <<(work)
        @queue_server << work
      end

      def size
        @worker_count
      end

      # How long to wait for workers to exit during shutdown before
      # force-killing them. Must be long enough for normal cleanup
      # (parallelize_teardown hooks, DRb deregistration) but short
      # enough to avoid stalling CI pipelines indefinitely.
      SHUTDOWN_TIMEOUT = 30 # seconds

      def shutdown
        dead_worker_pids = @worker_pool.filter_map do |pid|
          Process.waitpid(pid, Process::WNOHANG)
        rescue Errno::ECHILD
          pid
        end
        @queue_server.remove_dead_workers(dead_worker_pids)

        @queue_server.shutdown(timeout: SHUTDOWN_TIMEOUT)

        if @queue_server.active_workers?
          force_kill_workers
          @queue_server.remove_dead_workers(@worker_pool)
        else
          wait_for_workers
        end
      end

      private
        def wait_for_workers
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + SHUTDOWN_TIMEOUT

          @worker_pool.each do |pid|
            remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)

            if remaining <= 0
              force_kill_workers
              @queue_server.remove_dead_workers(@worker_pool)
              return
            end

            wait_for_worker(pid, remaining)
          end
        end

        def wait_for_worker(pid, timeout)
          deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

          loop do
            return if Process.waitpid(pid, Process::WNOHANG)

            if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
              force_kill_workers
              @queue_server.remove_dead_workers(@worker_pool)
              return
            end

            sleep 0.1
          end
        rescue Errno::ECHILD
          nil
        end

        def force_kill_workers
          @worker_pool.each do |pid|
            Process.kill("KILL", pid)
          rescue Errno::ESRCH
            nil
          end

          @worker_pool.each do |pid|
            Process.waitpid(pid)
          rescue Errno::ECHILD
            nil
          end
        end
    end
  end
end
