module ActiveRecord
  class PredicateBuilder
    class AssociationQueryHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        queries = {}

        table = value.associated_table
        if value.base_class
          queries[table.association_foreign_type] = value.base_class.name
        end

        queries[table.association_foreign_key] = value.ids
        predicate_builder.build_from_hash(queries)
      end

      protected

      attr_reader :predicate_builder
    end

    class AssociationQueryValue # :nodoc:
      attr_reader :associated_table, :value

      def initialize(associated_table, value)
        @associated_table = associated_table
        @value = value
      end

      def ids
        value
      end

      def base_class
        if associated_table.polymorphic_association?
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
