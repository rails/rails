module ActiveRecord
  class PredicateBuilder
    class AssociationQueryHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        queries = {}

        if value.base_class
          queries[value.association.foreign_type] = value.base_class.name
        end

        queries[value.association.foreign_key] = value.ids
        predicate_builder.build_from_hash(queries)
      end

      protected

      attr_reader :predicate_builder
    end

    class AssociationQueryValue # :nodoc:
      attr_reader :association, :value

      def initialize(association, value)
        @association = association
        @value = value
      end

      def ids
        value
      end

      def base_class
        if association.polymorphic?
          @base_class ||= polymorphic_base_class_from_value
        end
      end

      private

      def polymorphic_base_class_from_value
        case value
        when Relation
          value.klass.base_class
        when Array
          val = value.compact.first
          val.class.base_class if val.is_a?(Base)
        when Base
          value.class.base_class
        end
      end
    end
  end
end
