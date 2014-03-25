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

      def start;  self; end
      def finish; self; end

      def add_bind bind
        self << bind
        self
      end
    end
  end
end
