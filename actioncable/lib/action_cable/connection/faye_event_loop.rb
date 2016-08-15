require "thread"

require "eventmachine"
EventMachine.epoll  if EventMachine.epoll?
EventMachine.kqueue if EventMachine.kqueue?

module ActionCable
  module Connection
    class FayeEventLoop
      @@mutex = Mutex.new

      def timer(interval, &block)
        ensure_reactor_running
        EMTimer.new(::EM::PeriodicTimer.new(interval, &block))
      end

      def post(task = nil, &block)
        task ||= block

        ensure_reactor_running
        ::EM.next_tick(&task)
      end

      private
        def ensure_reactor_running
          return if EventMachine.reactor_running?
          @@mutex.synchronize do
            Thread.new { EventMachine.run } unless EventMachine.reactor_running?
            Thread.pass until EventMachine.reactor_running?
          end
        end

        class EMTimer
          def initialize(inner)
            @inner = inner
          end

          def shutdown
            @inner.cancel
          end
        end
    end
  end
end
