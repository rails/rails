# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?
require "concurrent/array"

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      PrerecordResultClass = Struct.new(:name)

      class Server
        include DRb::DRbUndumped
        def initialize(distributor:)
          @distributor = distributor
          @active_workers = Concurrent::Map.new
          @worker_pids = Concurrent::Map.new
          @in_flight = Concurrent::Map.new
          @worker_errors = Concurrent::Array.new
          @reporter = nil
        end

        def record(reporter, result)
          @reporter = reporter

          raise DRb::DRbConnError if result.is_a?(DRb::DRbUnknown)

          @in_flight.delete([result.klass, result.name])

          reporter.synchronize do
            reporter.prerecord(PrerecordResultClass.new(result.klass), result.name)
            reporter.record(result)
          end
        end

        def <<(o)
          o[2] = DRbObject.new(o[2]) if o
          @distributor.add_test(o)
        end

        def pop(worker_id)
          if test = @distributor.take(worker_id: worker_id)
            @in_flight[[test[0].to_s, test[1]]] = test
          end

          test
        end

        def start_worker(worker_id, worker_pid)
          @active_workers[worker_id] = true
          @worker_pids[worker_id] = worker_pid
        end

        def stop_worker(worker_id)
          @active_workers.delete(worker_id)
          @worker_pids.delete(worker_id)
        end

        # Records an error raised by a worker's parallelize_teardown hooks.
        # The error is reported as a failed result by #record_worker_errors,
        # so the test run fails instead of passing silently.
        def report_worker_error(worker_number, error)
          @worker_errors << [worker_number, error]
          nil
        end

        # Records each worker cleanup failure as a failed result, so the
        # run is reported as failed. If no test result was ever recorded
        # there is no reporter to record the failures with, so raise
        # instead: the run must not pass silently.
        #
        # Must be called after all workers have exited (see
        # Parallelization#shutdown): a worker that has not finished its
        # cleanup yet may still report an error.
        def record_worker_errors
          return if @worker_errors.empty?

          if @reporter.nil?
            failures = @worker_errors.map { |worker_number, error|
              "worker #{worker_number}: #{error.class}: #{error.message}"
            }.join("; ")
            raise "parallelize_teardown failed (#{failures})"
          end

          @worker_errors.each do |(worker_number, error)|
            result = Minitest::Result.new("parallelize_teardown")
            result.klass = "Parallelization worker #{worker_number}"
            result.time = 0
            result.failures << Minitest::UnexpectedError.new(error)
            @reporter.synchronize do
              @reporter.prerecord(PrerecordResultClass.new(result.klass), result.name)
              @reporter.record(result)
            end
          end
        end

        def remove_dead_workers(dead_pids)
          dead_pids.each do |dead_pid|
            if worker_id = @worker_pids.key(dead_pid)
              @active_workers.delete(worker_id)
              @worker_pids.delete(worker_id)
            end
          end
        end

        def active_workers?
          @active_workers.size > 0
        end

        def interrupt
          @distributor.interrupt
        end

        def shutdown
          # Wait for initial queue to drain
          while @distributor.pending?
            sleep 0.1
          end

          @distributor.close

          wait_for_active_workers

          @in_flight.values.each do |(klass, name, reporter)|
            result = Minitest::Result.from(klass.new(name))
            error = RuntimeError.new("result not reported")
            error.set_backtrace([""])
            result.failures << Minitest::UnexpectedError.new(error)
            reporter.synchronize do
              reporter.record(result)
            end
          end
        rescue Interrupt
          warn "Interrupted. Exiting..."

          @distributor.close

          wait_for_active_workers
        end

        private
          def wait_for_active_workers
            while active_workers?
              reap_dead_workers
              sleep 0.1
            end
          end

          def reap_dead_workers
            dead_pids = @worker_pids.values.select do |pid|
              Process.waitpid(pid, Process::WNOHANG)
            rescue Errno::ECHILD
              true
            end

            remove_dead_workers(dead_pids)
          end
      end
    end
  end
end
