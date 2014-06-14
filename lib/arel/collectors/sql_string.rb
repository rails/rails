# encoding: utf-8

require 'arel/collectors/plain_string'

module Arel
  module Collectors
    class SQLString < PlainString
      def add_bind bind
        self << bind.to_s
        self
      end

      def compile bvs
        value
      end
    end
  end
end
