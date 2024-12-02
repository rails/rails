# frozen_string_literal: true

require "delegate"

module ActiveSupport
  # This is a class for wrapping syntax errors.  The purpose of this class
  # is to enhance the backtraces on SyntaxError exceptions to include the
  # source location of the syntax error.  That way we can display the error
  # source on error pages in development.
  class SyntaxErrorProxy < DelegateClass(SyntaxError) # :nodoc:
    def backtrace
      parse_message_for_trace + super
    end

    class BacktraceLocation < Struct.new(:path, :lineno, :to_s) # :nodoc:
      def spot(_)
      end

      def label
      end

      def base_label
      end
    end

    class BacktraceLocationProxy < DelegateClass(Thread::Backtrace::Location) # :nodoc:
      def initialize(loc, ex)
        super(loc)
        @ex = ex
      end

      def spot(_)
        super(@ex.__getobj__)
      end
    end

    def backtrace_locations
      return nil if super.nil?

      parse_message_for_trace.map { |trace|
        file, line = trace.match(/^(.+?):(\d+).*$/, &:captures) || trace
        BacktraceLocation.new(file, line.to_i, trace)
        # We have to wrap these backtrace locations because we need the
        # spot information to come from the originating exception, not the
        # proxy object that's generating these
      } + super.map { |loc| BacktraceLocationProxy.new(loc, self) }
    end

    private
      def parse_message_for_trace
        if __getobj__.to_s.start_with?("(eval")
          # If the exception is coming from a call to eval, we need to keep
          # the path of the file in which eval was called to ensure we can
          # return the right source fragment to show the location of the
          # error
          location = __getobj__.backtrace_locations[0]
          ["#{location.path}:#{location.lineno}: #{__getobj__}"]
        else
          __getobj__.to_s.split("\n")
        end
      end
  end
end
