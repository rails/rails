module Bundler
  module Resolver
    class Stack
      def initialize(initial = [])
        @data = []
        initial.each do |(path,value)|
          self[path] = value
        end
      end

      def last
        @data.last
      end

      def []=(path, value)
        raise ArgumentError, "#{path.inspect} already has a value" if key?(path)
        @data << [path.dup, value]
      end

      def [](path)
        if key?(path)
          _, value = @data.find do |(k,v)|
            k == path
          end
          value
        else
          raise "No value for #{path.inspect}"
        end
      end

      def key?(path)
        @data.any? do |(k,v)|
          k == path
        end
      end

      def each
        @data.each do |(k,v)|
          yield k, v
        end
      end

      def map
        @data.map do |(k,v)|
          yield k, v
        end
      end

      def each_value
        @data.each do |(k,v)|
          yield v
        end
      end

      def dup
        self.class.new(@data.dup)
      end

      def to_s
        @data.to_s
      end

      def inspect
        @data.inspect
      end

      def gem_resolver_inspect
        Inspect.gem_resolver_inspect(@data)
      end
    end
  end
end