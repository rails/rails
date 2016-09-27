require "nio"
require "thread"

module ActionCable
  module Connection
    class StreamEventLoop
      def initialize
        @nio = @executor = @thread = nil
        @map = {}
        @stopping = false
        @todo = Queue.new

        @spawn_mutex = Mutex.new
      end

      def timer(interval, &block)
        Concurrent::TimerTask.new(execution_interval: interval, &block).tap(&:execute)
      end

      def post(task = nil, &block)
        task ||= block

        spawn
        @executor << task
      end

      def attach(io, stream)
        @todo << lambda do
          @map[io] = @nio.register(io, :r)
          @map[io].value = stream
        end
        wakeup
      end

      def detach(io, stream)
        @todo << lambda do
          @nio.deregister io
          @map.delete io
        end
        wakeup
      end

      def writes_pending(io)
        @todo << lambda do
          if monitor = @map[io]
            monitor.interests = :rw
          end
        end
        wakeup
      end

      def stop
        @stopping = true
        wakeup if @nio
      end

      private
        def spawn
          return if @thread && @thread.status

          @spawn_mutex.synchronize do
            return if @thread && @thread.status

            @nio ||= NIO::Selector.new

            @executor ||= Concurrent::ThreadPoolExecutor.new(
              min_threads: 1,
              max_threads: 10,
              max_queue: 0,
            )

            @thread = Thread.new { run }

            return true
          end
        end

        def wakeup
          spawn || @nio.wakeup
        end

        def run
          loop do
            if @stopping
              @nio.close
              break
            end

            until @todo.empty?
              @todo.pop(true).call
            end

            next unless monitors = @nio.select

            monitors.each do |monitor|
              io = monitor.io
              stream = monitor.value

              begin
                if monitor.writable?
                  if stream.flush_write_buffer
                    monitor.interests = :r
                  end
                  next unless monitor.readable?
                end

                incoming = io.read_nonblock(4096, exception: false)
                case incoming
                when :wait_readable
                  next
                when nil
                  stream.close
                else
                  stream.receive incoming
                end
              rescue
                # We expect one of EOFError or Errno::ECONNRESET in
                # normal operation (when the client goes away). But if
                # anything else goes wrong, this is still the best way
                # to handle it.
                begin
                  stream.close
                rescue
                  @nio.deregister io
                  @map.delete io
                end
              end
            end
          end
        end
    end
  end
end
