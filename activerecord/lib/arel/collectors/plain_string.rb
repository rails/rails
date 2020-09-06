# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class PlainString
      def initialize
        @str = +''
      end

      def value
        @str
      end

      def <<(str)
        @str << str
        self
      end
    end
  end
end
