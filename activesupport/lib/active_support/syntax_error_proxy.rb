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

    class BacktraceLocation < Struct.new(:path, :lineno, :to_s)
    end

    def backtrace_locations
      parse_message_for_trace.map { |trace|
        file, line = trace.match(/^(.+?):(\d+).*$/, &:captures) || trace
        BacktraceLocation.new(file, line.to_i, trace)
      } + super
    end

    private
      def parse_message_for_trace
        __getobj__.to_s.split("\n")
      end
  end
end
