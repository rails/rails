class Thor
  module CoreExt #:nodoc:

    # A hash with indifferent access and magic predicates.
    #
    #   hash = Thor::CoreExt::HashWithIndifferentAccess.new 'foo' => 'bar', 'baz' => 'bee', 'force' => true
    #
    #   hash[:foo]  #=> 'bar'
    #   hash['foo'] #=> 'bar'
    #   hash.foo?   #=> true
    #
    class HashWithIndifferentAccess < ::Hash #:nodoc:

      def initialize(hash={})
        super()
        hash.each do |key, value|
          self[convert_key(key)] = value
        end
      end

      def [](key)
        super(convert_key(key))
      end

      def []=(key, value)
        super(convert_key(key), value)
      end

      def delete(key)
        super(convert_key(key))
      end

      def values_at(*indices)
        indices.collect { |key| self[convert_key(key)] }
      end

      def merge(other)
        dup.merge!(other)
      end

      def merge!(other)
        other.each do |key, value|
          self[convert_key(key)] = value
        end
        self
      end

      protected

        def convert_key(key)
          key.is_a?(Symbol) ? key.to_s : key
        end

        # Magic predicates. For instance:
        #
        #   options.force?                  # => !!options['force']
        #   options.shebang                 # => "/usr/lib/local/ruby"
        #   options.test_framework?(:rspec) # => options[:test_framework] == :rspec
        #
        def method_missing(method, *args, &block)
          method = method.to_s
          if method =~ /^(\w+)\?$/
            if args.empty?
              !!self[$1]
            else
              self[$1] == args.first
            end
          else 
            self[method]
          end
        end

    end
  end
end
