# frozen_string_literal: true

require "delegate"

module ActiveSupport
  # This is a class for wrapping syntax errors.  The purpose of this class
  # is to enhance the backtraces on SyntaxError exceptions to include the
  # source location of the syntax error.  That way we can display the error
  # source on error pages in development.
  class SyntaxErrorProxy < DelegateClass(SyntaxError) # :nodoc:
    def backtrace
      (__getobj__.to_s.split("\n") + super).flatten
    end
  end
end
