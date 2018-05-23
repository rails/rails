# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class SQLString < PlainString
      def initialize(*)
        super
        @bind_index = 1
      end

      def add_bind(bind)
        self << yield(@bind_index)
        @bind_index += 1
        self
      end

      def compile(bvs)
        value
      end
    end
  end
end
