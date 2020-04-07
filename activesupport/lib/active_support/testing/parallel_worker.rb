module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      class Worker
        def initialize(id, url)
          @id = id
          @url = url
          @title = "Rails test worker #{@id}"
          @setup_exception = nil
        end

        def start
          fork do
            Process.setproctitle("#{@title} - (starting)")

            DRb.stop_service

            begin
              after_fork
            rescue => @setup_exception; end

            @queue = DRbObject.new_with_uri(@url)

            work_from_queue
          ensure
            Process.setproctitle("#{@title} - (stopping)")

            run_cleanup
          end
        end

        def work_from_queue
          while job = @queue.pop
            perform_job(job)
          end
        end

        def perform_job(job)
          klass    = job[0]
          method   = job[1]
          reporter = job[2]

          Process.setproctitle("#{@title} - #{klass}##{method}")

          result = klass.with_info_handler reporter do
            Minitest.run_one_method(klass, method)
          end

          safe_record(reporter, result)
        end

        def safe_record(reporter, result)
          add_setup_exception(result) if @setup_exception

          begin
            @queue.record(reporter, result)
          rescue DRb::DRbConnError
            result.failures.map! do |failure|
              if failure.respond_to?(:error)
                # minitest >5.14.0
                error = DRb::DRbRemoteError.new(failure.error)
              else
                error = DRb::DRbRemoteError.new(failure.exception)
              end
              Minitest::UnexpectedError.new(error)
            end
            @queue.record(reporter, result)
          end

          Process.setproctitle("#{@title} - (idle)")
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

        def after_fork
          self.class.after_fork_hooks.each do |cb|
            cb.call(@id)
          end
        end

        def run_cleanup
          self.class.run_cleanup_hooks.each do |cb|
            cb.call(@id)
          end
        end

        private
          def add_setup_exception(result)
            result.failures.prepend Minitest::UnexpectedError.new(@setup_exception)
          end
      end
    end
  end
end
