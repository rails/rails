# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?
require "active_support/core_ext/module/attribute_accessors"
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

      def initialize(worker_count)
        @worker_count = worker_count
        @queue_server = Server.new
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

      def shutdown
        dead_worker_pids = @worker_pool.filter_map do |pid|
          Process.waitpid(pid, Process::WNOHANG)
        rescue Errno::ECHILD
          pid
        end
        @queue_server.remove_dead_workers(dead_worker_pids)

        @queue_server.shutdown
        @worker_pool.each do |pid|
          Process.waitpid(pid)
        rescue Errno::ECHILD
          nil
        end
      end
    end
  end
end
