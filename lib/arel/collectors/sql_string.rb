# encoding: utf-8

module Arel
  module Collectors
    class SQLString
      def initialize
        @str = ''
      end

      def value
        @str
      end

      def << str
        @str << str
        self
      end

      def add_bind bind
        self << bind.to_s
        self
      end
    end
  end
end
