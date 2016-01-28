require 'nio'

module ActionCable
  module Connection
    class StreamEventLoop
      def initialize
        @nio = NIO::Selector.new
        @map = {}
        @stopping = false
        @todo = Queue.new

        Thread.new do
          Thread.current.abort_on_exception = true
          run
        end
      end

      def attach(io, stream)
        @todo << lambda do
          @map[io] = stream
          @nio.register(io, :r)
        end
        @nio.wakeup
      end

      def detach(io, stream)
        @todo << lambda do
          @nio.deregister(io)
          @map.delete io
        end
        @nio.wakeup
      end

      def stop
        @stopping = true
        @nio.wakeup
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

          if monitors = @nio.select
            monitors.each do |monitor|
              io = monitor.io
              stream = @map[io]

              begin
                stream.receive io.read_nonblock(4096)
              rescue IO::WaitReadable
                next
              rescue EOFError
                stream.close
              end
            end
          end
        end
      end
    end
  end
end
