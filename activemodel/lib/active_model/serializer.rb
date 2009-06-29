require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'

module ActiveModel
  class Serializer
    attr_reader :options

    def initialize(serializable, options = nil)
      @serializable = serializable
      @options = options ? options.dup : {}
    end

    def serialize
      raise NotImplemented
    end

    def to_s(&block)
      serialize(&block)
    end

    protected
      def serializable_attribute_names
        attribute_names = @serializable.attributes.keys

        if options[:only]
          only = Array.wrap(options[:only]).map { |n| n.to_s }
          attribute_names &= only
        elsif options[:except]
          except = Array.wrap(options[:except]).map { |n| n.to_s }
          attribute_names -= except
        end

        attribute_names
      end

      def serializable_method_names
        Array.wrap(options[:methods]).inject([]) do |methods, name|
          methods << name if @serializable.respond_to?(name.to_s)
          methods
        end
      end

      def serializable_names
        serializable_attribute_names + serializable_method_names
      end

      def serializable_hash
        serializable_names.inject({}) { |hash, name|
          hash[name] = @serializable.send(name)
          hash
        }
      end
  end
end
