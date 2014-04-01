module ActionDispatch
  module Routing # :nodoc:
    class SimpleScanner # :nodoc:
      def initialize(string)
        @array = string.scan /[^\/.]+/
      end

      def scan
        @array.shift
      end

      def finished?
        @array.empty?
      end
    end
  end
end
