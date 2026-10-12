# :markup: markdown
# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?

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
        end

        def record(reporter, result)
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

        def shutdown(worker_pids)
          @distributor.close

          wait_for_workers(worker_pids)

          # Dead workers may leave tests in their queues. Register those tests
          # as unreported after the surviving workers have finished.
          worker_pids.each_index do |worker_id|
            while pop(worker_id); end
          end

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

          wait_for_workers(worker_pids)
        end

        private
          def wait_for_workers(worker_pids)
            worker_pids.each do |pid|
              Process.waitpid(pid)
            rescue Errno::ECHILD
              nil
            end

            remove_dead_workers(worker_pids)
          end
      end
    end
  end
end
