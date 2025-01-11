# frozen_string_literal: true

require "tsort"

module Rails
  module Initializable
    def self.included(base) # :nodoc:
      base.extend ClassMethods
    end

    class Initializer
      attr_reader :name, :block, :before, :after

      def initialize(name, context, before:, after:, group: nil, &block)
        @group = group || :default
        @name, @before, @after, @context, @block = name, before, after, context, block
      end

      def belongs_to?(group)
        @group == group || @group == :all
      end

      def run(*args)
        @context.instance_exec(*args, &block)
      end

      def bind(context)
        return self if @context
        Initializer.new(@name, context, before:, after:, group: @group, &block)
      end

      def context_class
        @context.class
      end
    end

    class Collection
      include Enumerable
      include TSort

      delegate_missing_to :@collection

      def initialize(initializers = nil)
        @order = Hash.new { |hash, key| hash[key] = Set.new }
        @resolve = Hash.new { |hash, key| hash[key] = Set.new }
        @collection = []
        concat(initializers) if initializers
      end

      def to_a
        @collection
      end

      def last
        @collection.last
      end

      def each(&block)
        @collection.each(&block)
      end

      alias :tsort_each_node :each
      def tsort_each_child(initializer, &block)
        @order[initializer.name].each do |name|
          @resolve[name].each(&block)
        end
      end

      def +(other)
        dup.concat(other.to_a)
      end

      def <<(initializer)
        @collection << initializer
        @order[initializer.before] << initializer.name if initializer.before
        @order[initializer.name] << initializer.after if initializer.after
        @resolve[initializer.name] << initializer
        self
      end

      def push(*initializers)
        initializers.each(&method(:<<))
        self
      end

      alias_method(:append, :push)

      def concat(*initializer_collections)
        initializer_collections.each do |initializers|
          initializers.each(&method(:<<))
        end
        self
      end

      def has?(name)
        @resolve.key?(name)
      end
    end

    def run_initializers(group = :default, *args)
      return if instance_variable_defined?(:@ran)
      initializers.tsort_each do |initializer|
        initializer.run(*args) if initializer.belongs_to?(group)
      end
      @ran = true
    end

    def initializers
      @initializers ||= self.class.initializers_for(self)
    end

    module ClassMethods
      def initializers
        @initializers ||= Collection.new
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
        opts[:after] ||= initializers.last&.name unless initializers.has?(opts[:before])
        initializers << Initializer.new(
          name, nil, before: opts[:before], after: opts[:after], group: opts[:group], &blk
        )
      end
    end
  end
end
