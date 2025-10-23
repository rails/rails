# frozen_string_literal: true

require "drb"
require "drb/unix" unless Gem.win_platform?

module ActiveSupport
  module Testing
    class Parallelization # :nodoc:
      PrerecordResultClass = Struct.new(:name)

      class Server
        include DRb::DRbUndumped

        def initialize
          @queue = Queue.new
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
          @queue << o
        end

        def pop
          if test = @queue.pop
            @in_flight[[test[0].to_s, test[1]]] = test
            test
          end
        end

        def start_worker(worker_id, worker_pid)
          @active_workers[worker_id] = true
          @worker_pids[worker_id] = worker_pid
        end

        def stop_worker(worker_id, worker_pid)
          @active_workers.delete(worker_id)
          @worker_pids.delete(worker_id)
        end

        def remove_dead_workers(dead_pids)
          dead_pids.each do |dead_pid|
            worker_id = @worker_pids.key(dead_pid)
            if worker_id
              @active_workers.delete(worker_id)
              @worker_pids.delete(worker_id)
            end
          end
        end

        def active_workers?
          @active_workers.size > 0
        end

        def interrupt
          @queue.clear
        end

        def shutdown
          # Wait for initial queue to drain
          while @queue.length != 0
            sleep 0.1
          end

          @queue.close

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

          @queue.close

          wait_for_active_workers
        end

        private
          def wait_for_active_workers
            while active_workers?
              sleep 0.1
            end
          end
      end
    end
  end
end
