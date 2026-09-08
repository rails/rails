# frozen_string_literal: true

require "arel/collectors/plain_string"

module Arel # :nodoc: all
  module Collectors
    class SQLString < PlainString
      attr_accessor :preparable, :retryable

      def initialize(*)
        super
        @bind_index = 1
      end

      def add_bind(bind, &)
        self << yield(@bind_index)
        @bind_index += 1
        self
      end

      def add_binds(binds, proc_for_binds = nil, &block)
        self << (@bind_index...@bind_index += binds.size).map(&block).join(", ")
        self
      end
    end
  end
end
