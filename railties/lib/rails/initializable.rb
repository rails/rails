module Rails
  module Initializable
    def self.included(base)
      base.extend ClassMethods
    end

    class Initializer
      attr_reader :name, :block

      def initialize(name, context, options, &block)
        @name, @context, @options, @block = name, context, options, block
      end

      def before
        @options[:before]
      end

      def after
        @options[:after]
      end

      def run(*args)
        @context.instance_exec(*args, &block)
      end

      def bind(context)
        return self if @context
        Initializer.new(@name, context, @options, &block)
      end
    end

    class Collection < Array
      def initialize(initializers = [])
        super()
        initializers.each do |initializer|
          if initializer.before
            index = index_for(initializer.before)
          elsif initializer.after
            index = index_for(initializer.after)
            index += 1 if index
          else
            index = length
          end
          insert(index || -1, initializer)
        end
      end

      def +(other)
        Collection.new(to_a + other.to_a)
      end

      def index_for(name)
        initializer = find { |i| i.name == name }
        initializer && index(initializer)
      end
    end

    def run_initializers(*args)
      return if instance_variable_defined?(:@ran)
      initializers.each do |initializer|
        initializer.run(*args)
      end
      @ran = true
    end

    def initializers
      @initializers ||= self.class.initializers_for(self)
    end

    module ClassMethods
      def initializers
        @initializers ||= []
      end

      def initializers_chain
        initializers = Collection.new
        ancestors.reverse_each do |klass|
          next unless klass.respond_to?(:initializers)
          initializers = initializers + klass.initializers
        end
        initializers
      end

      def initializers_for(binding)
        Collection.new(initializers_chain.map { |i| i.bind(binding) })
      end

      def initializer(name, opts = {}, &blk)
        raise ArgumentError, "A block must be passed when defining an initializer" unless blk
        initializers << Initializer.new(name, nil, opts, &blk)
      end

      def run_initializers(*args)
        return if @ran
        initializers_chain.each do |initializer|
          instance_exec(*args, &initializer.block)
        end
        @ran = true
      end
    end
  end
end