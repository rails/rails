# frozen_string_literal: true

module ActiveRecord
  class PredicateBuilder
    class AssociationQueryValue # :nodoc:
      def initialize(reflection, value, origin_class)
        @reflection = reflection
        @value = value
        @origin_class = origin_class
      end

      def queries
        ensure_ids_are_sufficient!

        if value.nil?
          [nil_query]
        elsif value.is_a?(Array)
          queries_for_array(value)
        else
          queries_for_route(value, association_route_for(value))
        end
      end

      private
        attr_reader :reflection, :value

        def queries_for_array(values)
          if values.none? { |item| item.nil? || record_or_relation?(item) }
            return queries_for_route(values, association_route_for(nil))
          end

          items_by_route = values.group_by { |item| association_route_for(item) unless item.nil? }
          nils = items_by_route.delete(nil)
          queries = items_by_route.flat_map { |route, items| queries_for_route(items, route) }
          queries << nil_query if nils
          queries
        end

        def ensure_ids_are_sufficient!
          return if association_route_for(nil).predicate_accepts_bare_id?

          items = value.is_a?(Array) ? value : [value]
          if items.any? { |item| !item.nil? && !record_or_relation?(item) }
            raise ArgumentError, "#{reflection.active_record}##{reflection.name} matches on more than one column, " \
              "so it must be queried with records or relations rather than ids"
          end
        end

        def queries_for_route(query_value, route)
          id_list = ids(query_value, route)
          id_list = id_list.pluck(route.destination_key.name) if route.origin_key.composite? && id_list.is_a?(Relation)

          route.origin_key.where_clauses(id_list)
        end

        def nil_query
          # Query-constraint columns may still be populated when a reference is
          # unset, so a nil query should only match against the reference columns.
          key = association_route_for(nil).reference_origin_key
          key.where_hash(key.map_value { nil })
        end

        def ids(query_value, route)
          destination_key = route.destination_key
          case query_value
          when Relation
            relation = query_value
            relation = relation.select(destination_key.name) if relation.select_values.empty?
            route.destination_fixed_values.each do |column, value|
              physical_column = relation.model.attribute_aliases[column] || column
              unless relation.where_values_hash.has_key?(physical_column)
                relation = relation.where(column => value)
              end
            end
            relation
          when Array
            query_value.map { |item| convert_to_id(item, destination_key) }
          else
            [convert_to_id(query_value, destination_key)]
          end
        end

        def association_route_for(target)
          destination_class = case target
          when Relation
            target.model
          when Base
            target.class
          else
            reflection.klass
          end
          (@routes ||= {})[destination_class] ||= reflection.association_route(origin_class: @origin_class, destination_class: destination_class)
        end

        def record_or_relation?(target)
          target.is_a?(Base) || target.is_a?(Relation)
        end

        def convert_to_id(value, destination_key)
          if value.is_a?(Base)
            destination_key.value_of(value)
          elsif value.respond_to?(destination_key.name)
            value.public_send(destination_key.name)
          else
            value
          end
        end
    end
  end
end
