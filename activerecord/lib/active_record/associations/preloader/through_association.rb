# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      module ThroughAssociation #:nodoc:
        def through_reflection
          reflection.through_reflection
        end

        def source_reflection
          reflection.source_reflection
        end

        def associated_records_by_owner(preloader)
          already_loaded = owners.first.association(through_reflection.name).loaded?
          through_scope = through_scope()

          unless already_loaded
            preloader.preload(owners, through_reflection.name, through_scope)
          end

          through_records = owners.map do |owner|
            center = owner.association(through_reflection.name).target
            [owner, Array(center)]
          end

          if already_loaded
            if source_type = reflection.options[:source_type]
              through_records.map! do |owner, center|
                center = center.select do |record|
                  record[reflection.foreign_type] == source_type
                end
                [owner, center]
              end
            end
          else
            reset_association(owners, through_reflection.name, through_scope)
          end

          middle_records = through_records.flat_map(&:last)

          if preload_scope
            reflection_scope = reflection_scope().merge(preload_scope)
          elsif reflection.scope
            reflection_scope = reflection_scope()
          end

          preloaders = preloader.preload(middle_records,
                                         source_reflection.name,
                                         reflection_scope)

          @preloaded_records = preloaders.flat_map(&:preloaded_records)

          middle_to_pl = preloaders.each_with_object({}) do |pl, h|
            pl.owners.each { |middle|
              h[middle] = pl
            }
          end

          through_records.each_with_object({}) do |(lhs, center), records_by_owner|
            pl_to_middle = center.group_by { |record| middle_to_pl[record] }

            records_by_owner[lhs] = pl_to_middle.flat_map do |pl, middles|
              rhs_records = middles.flat_map { |r|
                r.association(source_reflection.name).target
              }.compact

              # Respect the order on `reflection_scope` if it exists, else use the natural order.
              if reflection_scope && !reflection_scope.order_values.empty?
                @id_map ||= id_to_index_map @preloaded_records
                rhs_records.sort_by { |rhs| @id_map[rhs] }
              else
                rhs_records
              end
            end
          end.tap do
            reset_association(middle_records, source_reflection.name, preload_scope)
          end
        end

        private

          def id_to_index_map(ids)
            id_map = {}
            ids.each_with_index { |id, index| id_map[id] = index }
            id_map
          end

          def reset_association(owners, association_name, should_reset)
            # Don't cache the association - we would only be caching a subset
            if should_reset
              owners.each { |owner|
                owner.association(association_name).reset
              }
            end
          end

          def through_scope
            scope = through_reflection.klass.unscoped
            options = reflection.options

            if options[:source_type]
              scope.where! reflection.foreign_type => options[:source_type]
            elsif !reflection_scope.where_clause.empty?
              scope.where_clause = reflection_scope.where_clause
              values = reflection_scope.values

              if includes = values[:includes]
                scope.includes!(source_reflection.name => includes)
              else
                scope.includes!(source_reflection.name)
              end

              if values[:references] && !values[:references].empty?
                scope.references!(values[:references])
              else
                scope.references!(source_reflection.table_name)
              end

              if joins = values[:joins]
                scope.joins!(source_reflection.name => joins)
              end

              if left_outer_joins = values[:left_outer_joins]
                scope.left_outer_joins!(source_reflection.name => left_outer_joins)
              end

              if scope.eager_loading? && order_values = values[:order]
                scope = scope.order(order_values)
              end
            end

            scope unless scope.empty_scope?
          end
      end
    end
  end
end
