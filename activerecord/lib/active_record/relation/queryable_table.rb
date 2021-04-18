# frozen_string_literal: true

module ActiveRecord
  class QueryableTable # :nodoc:
    def initialize(model)
      @model = model
      @arel_table = model.arel_table
      @reflections = model._reflections
      @attribute_nodes = {}
      define_attribute_accessors
    end

    def method_missing(name, *_args)
      if reflections.key?(name.to_s)
        self.class.new(reflections[name.to_s].klass)
      else
        super
      end
    end

    def inspect
      "#<#{self.class.name}:#{'%#016x' % (object_id << 1)} @model=#{@model}>"
    end

    private
      attr_reader :model, :arel_table, :reflections

      def define_attribute_accessors
        model.attribute_names.each do |attr|
          define_singleton_method attr do
            @attribute_nodes[attr] ||= Predicatable.new(arel_table[attr])
          end
        end
      end

      class Predicatable
        MAPPED_METHODS = [
          :eq,
          :not_eq,
          :gt,
          :gteq,
          :lt,
          :lteq,
          :in,
          :not_in,
          :and,
          :or,
          :matches,
          :does_not_match
        ]

        def initialize(arel_node)
          @arel_node = arel_node
        end

        MAPPED_METHODS.each do |method|
          define_method method do |other|
            other = other.arel_node if other.is_a?(self.class)
            Predicatable.new(arel_node.public_send(method, other))
          end
        end

        def to_arel
          arel_node
        end

        protected
          attr_reader :arel_node
      end
  end
end
