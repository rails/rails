# :markup: markdown
# frozen_string_literal: true

require "active_model/attribute"

module ActiveModel
  module StoreAttribute # :nodoc:
    # Describes how a store-attribute maps into a parent Hash-valued attribute.
    Definition = Data.define(:backed_by, :key) do # :nodoc:
      def build_attribute(name, attribute_set)
        Attribute.new(name, self, attribute_set)
      end

      def read(store)
        store[key] if store
      end

      def write(store, value)
        store ||= {}
        return store if store[key] == value
        new_store = store.dup
        new_store[key] = value
        new_store
      end

      def validate!(_parent)
      end
    end

    # Virtual attribute synthesized on lookup from a `Definition`;
    # delegates reads and writes to a parent Hash-valued attribute.
    class Attribute < ActiveModel::Attribute # :nodoc:
      def initialize(name, definition, attribute_set)
        @definition = definition
        @attribute_set = attribute_set
        super(name, nil, Type.default_value)
        definition.validate!(parent)
      end

      def value(&)
        definition.read(parent_value)
      end

      def value_before_type_cast
        definition.read(parent_value)
      end

      def original_value
        definition.read(parent_original_value)
      end

      def value_for_database
        type.serialize(value)
      end

      def changed?
        return false unless parent.changed?
        definition.read(parent_original_value) != definition.read(parent_value)
      end

      def came_from_user?
        parent.came_from_user?
      end

      def with_value_from_user(value)
        new_parent = definition.write(parent_value, value)
        attribute_set.write_from_user(definition.backed_by, new_parent)
        self
      end

      def with_value_from_database(_value)
        self
      end

      def with_cast_value(_value)
        self
      end

      def with_type(_type)
        self
      end

      def ==(other)
        self.class == other.class &&
          name == other.name &&
          definition == other.definition &&
          attribute_set.equal?(other.attribute_set)
      end
      alias eql? ==

      def hash
        [self.class, name, definition, attribute_set].hash
      end

      protected
        attr_reader :definition, :attribute_set

      private
        def parent
          attribute_set[definition.backed_by]
        end

        def parent_value
          parent.value
        end

        def parent_original_value
          parent.original_value
        end
    end
  end
end
