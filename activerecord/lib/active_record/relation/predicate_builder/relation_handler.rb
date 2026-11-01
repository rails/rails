# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class RelationHandler # :nodoc:
      def call(attribute, value)
        if value.eager_loading?
          value = value.send(:apply_join_dependency)
        end

        if value.select_values.empty?
          model = value.model
          if model.composite_primary_key?
            raise ArgumentError, "Cannot map composite primary key #{model.primary_key} to #{attribute.name}"
          else
            value = value.select(value.table[model.primary_key])
          end
        end

        query = value.arel
        if attribute.is_a?(ComparisonAttribute)
          query = query.clone
          query.projections = query.projections.map { |projection| comparison_projection(attribute, projection) }
        end

        attribute.in(query)
      end

      private
        def comparison_projection(attribute, projection)
          if projection.is_a?(Arel::Nodes::As)
            Arel::Nodes::As.new(attribute.comparison_expression(projection.left), projection.right)
          else
            attribute.comparison_expression(projection)
          end
        end
    end
  end
end
