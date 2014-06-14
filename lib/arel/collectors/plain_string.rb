module Arel
  module Collectors
    class PlainString
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
    end
  end
end
