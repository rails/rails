# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class BuildMethod # :nodoc:
      def initialize(klass)
        @lookups = {}
        klass&.aggregate_reflections&.keys&.each do |aggregate|
          @lookups[aggregate] = :aggregate
        end

        # TODO: can I check `reflection.is_a?(ThroughReflection) instead?
        klass&._reflections&.each do |reflection, reflection_obj|
          @lookups[reflection] = :reflection
        end
      end

      def build_query(predicate_builder, table, key, value, attributes)
        self.send(@lookups[key] || :column, predicate_builder, table, key, value, attributes)
      end

      protected
        def column(predicate_builder, table, key, value, attributes)
          predicate_builder[key, value]
        end

        def reflection(predicate_builder, table, key, value, attributes)
          # Find the foreign key when using queries such as:
          # Post.where(author: author)
          #
          # For polymorphic relationships, find the foreign key and type:
          # PriceEstimate.where(estimate_of: treasure)
          associated_table = table.associated_table(key)
          if associated_table.polymorphic_association?
            value = [value] unless value.is_a?(Array)
            klass = PredicateBuilder::PolymorphicArrayValue
          elsif associated_table.through_association?
            return associated_table.predicate_builder.expand_from_hash(associated_table.primary_key => value)
          end

          klass ||= PredicateBuilder::AssociationQueryValue
          queries = klass.new(associated_table, value).queries.map! do |query|
            # If the query produced is identical to attributes don't go any deeper.
            # Prevents stack level too deep errors when association and foreign_key are identical.
            query == attributes ? predicate_builder[key, value] : predicate_builder.expand_from_hash(query)
          end

          predicate_builder.grouping_queries(queries)
        end

        def aggregate(predicate_builder, table, key, value, attributes)
          mapping = table.reflect_on_aggregation(key).mapping
          values = value.nil? ? [nil] : Array.wrap(value)
          if mapping.length == 1 || values.empty?
            column_name, aggr_attr = mapping.first
            values = values.map do |object|
              object.respond_to?(aggr_attr) ? object.public_send(aggr_attr) : object
            end
            predicate_builder[column_name, values]
          else
            queries = values.map do |object|
              mapping.map do |field_attr, aggregate_attr|
                predicate_builder[field_attr, object.try!(aggregate_attr)]
              end
            end

            predicate_builder.grouping_queries(queries)
          end
        end
    end
  end
end
