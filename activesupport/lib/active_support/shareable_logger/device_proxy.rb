# frozen_string_literal: true

require "active_support/shareable_logger/writer"

module ActiveSupport
  class ShareableLogger # :nodoc:
    class DeviceProxy # :nodoc:
      def initialize(*args, **logdev_options)
        @writer = Writer.spawn(*args, **logdev_options)
        @closed = false
      end

      # Logger::LogDevice#write contract: returns the number of bytes written.
      def write(message)
        return if @closed

        @writer.async(message)
        message.bytesize
      end

      def flush
        @writer.flush unless @closed
        true
      end

      def close
        return true if @closed

        @writer.shutdown
        @closed = true unless frozen?
        true
      end

      def reopen(log = nil, **options)
        @writer.reopen(log, options) unless @closed
        self
      end
    end
  end
end
