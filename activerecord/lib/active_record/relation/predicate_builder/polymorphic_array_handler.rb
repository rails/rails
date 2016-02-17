module ActiveRecord
  class PredicateBuilder
    class PolymorphicArrayHandler # :nodoc:
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        table = value.associated_table
        queries = value.type_to_ids_mapping.map do |type, ids|
          { table.association_foreign_type.to_s => type, table.association_foreign_key.to_s => ids }
        end

        predicates = queries.map { |query| predicate_builder.build_from_hash(query) }

        if predicates.size > 1
          type_and_ids_predicates = predicates.map { |type_predicate, id_predicate| Arel::Nodes::Grouping.new(type_predicate.and(id_predicate)) }
          type_and_ids_predicates.inject(&:or)
        else
          predicates.first
        end
      end

      protected

      attr_reader :predicate_builder
    end

    class PolymorphicArrayValue # :nodoc:
      attr_reader :associated_table, :values

      def initialize(associated_table, values)
        @associated_table = associated_table
        @values = values
      end

      def type_to_ids_mapping
        default_hash = Hash.new { |hsh, key| hsh[key] = [] }
        values.each_with_object(default_hash) { |value, hash| hash[base_class(value).name] << convert_to_id(value) }
      end

      private

      def primary_key(value)
        associated_table.association_primary_key(base_class(value))
      end

      def base_class(value)
        value.class.base_class
      end

      def convert_to_id(value)
        value._read_attribute(primary_key(value))
      end
    end
  end
end
