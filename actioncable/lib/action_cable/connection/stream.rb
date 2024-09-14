# frozen_string_literal: true

# :markup: markdown

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
        @stream_send   = socket.env["stream.send"]

        @rack_hijack_io = nil
        @write_lock = Mutex.new

        @write_head = nil
        @write_buffer = Queue.new
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
        if @stream_send
          return @stream_send.call(data)
        end

        if @write_lock.try_lock
          begin
            if @write_head.nil? && @write_buffer.empty?
              written = @rack_hijack_io.write_nonblock(data, exception: false)

              case written
              when :wait_writable
                # proceed below
              when data.bytesize
                return data.bytesize
              else
                @write_head = data.byteslice(written, data.bytesize)
                @event_loop.writes_pending @rack_hijack_io

                return data.bytesize
              end
            end
          ensure
            @write_lock.unlock
          end
        end

        @write_buffer << data
        @event_loop.writes_pending @rack_hijack_io

        data.bytesize
      rescue EOFError, Errno::ECONNRESET
        @socket_object.client_gone
      end

      def flush_write_buffer
        @write_lock.synchronize do
          loop do
            if @write_head.nil?
              return true if @write_buffer.empty?
              @write_head = @write_buffer.pop
            end

            written = @rack_hijack_io.write_nonblock(@write_head, exception: false)
            case written
            when :wait_writable
              return false
            when @write_head.bytesize
              @write_head = nil
            else
              @write_head = @write_head.byteslice(written, @write_head.bytesize)
              return false
            end
          end
        end
      end

      def receive(data)
        @socket_object.parse(data)
      end

      def hijack_rack_socket
        return unless @socket_object.env["rack.hijack"]

        # This should return the underlying io according to the SPEC:
        @rack_hijack_io = @socket_object.env["rack.hijack"].call
        # Retain existing behavior if required:
        @rack_hijack_io ||= @socket_object.env["rack.hijack_io"]

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
