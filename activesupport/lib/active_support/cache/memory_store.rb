module ActiveSupport
  module Cache
    class MemoryStore < Store
      def initialize
        @data = {}
      end

      def read(name, options = nil)
        super
        @data[name]
      end

      def write(name, value, options = nil)
        super
        @data[name] = value
      end

      def delete(name, options = nil)
        super
        @data.delete(name)
      end

      def delete_matched(matcher, options = nil)
        super
        @data.delete_if { |k,v| k =~ matcher }
      end

      def exist?(name,options = nil)
        super
        @data.has_key?(name)
      end

      def clear
        @data.clear
      end
    end
  end
end