require 'active_support/concurrency/share_lock'

module ActiveSupport #:nodoc:
  module Dependencies #:nodoc:
    class Interlock
      def initialize # :nodoc:
        @lock = ActiveSupport::Concurrency::ShareLock.new
        @waiting = {}
        @waiting.extend(MonitorMixin)
        @watcher = nil
      end

      def start_timeout(timeout = 5)
        @watcher.kill if @watcher && @watcher.alive?
        @watcher = Thread.new do
          sleep(timeout)
          puts "Dependencies::Interlock has not moved in in #{timeout} seconds. There might be a deadlock."
        end
      end

      def start_watch
        @waiting.synchronize do
          @waiting[Thread.current] = true
          start_timeout
        end
      end

      def end_watch
        @waiting.synchronize do
          @waiting.delete(Thread.current)
          if @waiting.keys.empty?
            @watcher.kill
            @watcher = nil
          else
            start_timeout
          end
        end
      end

      def loading
        start_watch
        @lock.exclusive(purpose: :load, compatible: [:load], after_compatible: [:load]) do
          end_watch
          yield
        end
      end

      def unloading
        start_watch
        @lock.exclusive(purpose: :unload, compatible: [:load, :unload], after_compatible: [:load, :unload]) do
          end_watch
          yield
        end
      end

      def start_unloading
        start_watch
        @lock.start_exclusive(purpose: :unload, compatible: [:load, :unload])
        end_watch
      end

      def done_unloading
        @lock.stop_exclusive(compatible: [:load, :unload])
      end

      def start_running
        @lock.start_sharing
      end

      def done_running
        @lock.stop_sharing
      end

      def running
        @lock.sharing do
          yield
        end
      end

      def permit_concurrent_loads
        @lock.yield_shares(compatible: [:load]) do
          yield
        end
      end
    end
  end
end
