module ActionCable
  module Connection
    #--
    # This class is heavily based on faye-websocket-ruby
    #
    # Copyright (c) 2010-2015 James Coglan
    class Stream # :nodoc:
      def initialize(event_loop, socket)
        @event_loop    = event_loop
        @socket_object = socket
        @stream_send   = socket.env['stream.send']

        @rack_hijack_io = nil
        @write_lock = Mutex.new
      end

      def each(&callback)
        @stream_send ||= callback
      end

      def close
        shutdown
        @socket_object.client_gone
      end

      def shutdown
        clean_rack_hijack
      end

      def write(data)
        @write_lock.lock
        return @rack_hijack_io.write(data) if @rack_hijack_io
        return @stream_send.call(data) if @stream_send
      rescue EOFError, Errno::ECONNRESET
        @socket_object.client_gone
      ensure
        @write_lock.unlock
      end

      def receive(data)
        @socket_object.parse(data)
      end

      def hijack_rack_socket
        return unless @socket_object.env['rack.hijack']

        @socket_object.env['rack.hijack'].call
        @rack_hijack_io = @socket_object.env['rack.hijack_io']

        @event_loop.attach(@rack_hijack_io, self)
      end

      private
        def clean_rack_hijack
          return unless @rack_hijack_io
          @event_loop.detach(@rack_hijack_io, self)
          @rack_hijack_io = nil
        end
    end
  end
end
