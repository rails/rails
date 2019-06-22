# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?
require "active_support/core_ext/module/attribute_accessors"

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
            DRb.stop_service

            begin
              after_fork(worker)
            rescue => setup_exception; end

            queue = DRbObject.new_with_uri(@url)

            while job = queue.pop
              klass    = job[0]
              method   = job[1]
              reporter = job[2]
              result = klass.with_info_handler reporter do
                Minitest.run_one_method(klass, method)
              end

              add_setup_exception(result, setup_exception) if setup_exception

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

      def <<(work)
        @queue << work
      end

      def shutdown
        @queue_size.times { @queue << nil }
        @pool.each { |pid| Process.waitpid pid }

        if @queue.length > 0
          raise "Queue not empty, but all workers have finished. This probably means that a worker crashed and #{@queue.length} tests were missed."
        end
      end

      private
        def add_setup_exception(result, setup_exception)
          result.failures.prepend Minitest::UnexpectedError.new(setup_exception)
        end
    end
  end
end
