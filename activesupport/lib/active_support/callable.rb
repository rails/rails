# frozen_string_literal: true

module ActiveSupport
  # An object that has case-equality to a Proc or Lambda by responding to #call.
  # This can be used to duck-type match in a case statement.
  module Callable
    # Whether the object responds to #call
    def self.===(other)
      other.respond_to?(:call)
    end
  end
end
