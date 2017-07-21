# frozen_string_literal: true
module Arel
  module Collectors
    class PlainString
      def initialize
        @str = ''.dup
      end

      def value
        @str
      end

      def << str
        @str << str
        self
      end
    end
  end
end
