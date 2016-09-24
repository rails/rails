module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def self.queries_for(table, column, value)
        associated_table = table.associated_table(column)
        klass = if associated_table.polymorphic_association?
          case Array === value ? value.first : value
          when Base, Relation
            value = [value] unless Array === value
            PolymorphicArrayValue
          else
            AssociationQueryValue
          end
        else
          AssociationQueryValue
        end

        klass.new(associated_table, value).queries
      end

      def initialize(table, value)
        @table = table
        @value = value
      end

      def queries
        [table.association_foreign_key.to_s => ids]
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :table, :value

      private

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

        def primary_key
          table.association_primary_key
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
