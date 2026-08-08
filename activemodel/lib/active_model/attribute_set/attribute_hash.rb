# :markup: markdown
# frozen_string_literal: true

module ActiveModel
  class AttributeSet
    # A `Hash` of `Attribute` objects that synthesizes virtual store-attribute
    # keys on lookup from `store_attribute_definitions`.
    class AttributeHash < Hash # :nodoc:
      def initialize(store_attribute_definitions = {})
        super()
        @store_attribute_definitions = store_attribute_definitions
        @virtual_cache = {}
        @attribute_set = nil
      end

      def [](name)
        super || virtual_attribute(name)
      end

      def rebind(attribute_set)
        @attribute_set = attribute_set
        @virtual_cache = {}
      end

      def initialize_dup(_)
        super
        @virtual_cache = {}
      end

      def initialize_clone(...)
        super
        @virtual_cache = {}
      end

      private
        def virtual_attribute(name)
          return unless (definition = @store_attribute_definitions[name])
          @virtual_cache[name] ||= definition.build_attribute(name, @attribute_set)
        end
    end
  end
end
