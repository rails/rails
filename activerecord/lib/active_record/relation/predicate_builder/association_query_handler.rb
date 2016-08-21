module ActiveRecord
  class PredicateBuilder
    class AssociationQueryHandler # :nodoc:
      def self.value_for(table, column, value)
        associated_table = table.associated_table(column)
        if associated_table.polymorphic_association?
          case value.is_a?(Array) ? value.first : value
          when Base, Relation
            value = [value] unless value.is_a?(Array)
            klass = PolymorphicArrayValue
          end
        end

        klass ||= AssociationQueryValue
        klass.new(associated_table, value)
      end

      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        table = value.associated_table
        queries = { table.association_foreign_key.to_s => value.ids }
        predicate_builder.build_from_hash(queries)
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
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
        case value
        when Relation
          value.select(primary_key)
        when Array
          value.map { |v| convert_to_id(v) }
        else
          convert_to_id(value)
        end
      end

      private

        def primary_key
          associated_table.association_primary_key
        end

        def convert_to_id(value)
          case value
          when Base
            value._read_attribute(primary_key)
          else
            value
          end
        end
    end
  end
end
