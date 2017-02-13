# encoding: utf-8
# frozen_string_literal: true

require 'arel/collectors/plain_string'

module Arel
  module Collectors
    class SQLString < PlainString
      def initialize(*)
        super
        @bind_index = 1
      end

      def add_bind bind
        self << yield(@bind_index)
        @bind_index += 1
        self
      end

      def compile bvs
        value
      end
    end
  end
end
