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
          through_scope = through_scope()

          through_preloaders = preloader.preload(owners,
                            through_reflection.name,
                            through_scope,
                            should_skip_setting_target?(owners, through_reflection.name, through_scope))

          through_records = through_preloaders.map { |pl| pl.loaded_associated_records_by_owner }.inject({}, :merge)

          middle_records = through_records.flat_map(&:last)

          if reflection.scope || preload_scope
            reflection_scope = reflection_scope()
            reflection_scope = reflection_scope.merge(preload_scope) if preload_scope
          end

          preloaders = preloader.preload(middle_records,
                                         source_reflection.name,
                                         reflection_scope,
                                         @skip_setting_target)

          @preloaded_records = preloaders.flat_map(&:preloaded_records)

          reflection_records = preloaders.map { |pl| pl.loaded_associated_records_by_owner }.inject({}, :merge)

          @loaded_associated_records_by_owner = through_records.each_with_object({}) do |(lhs, center), records_by_owner|
            rhs_records = Array(center).flat_map do |middle|
              reflection_records[middle]
            end.compact

            # Respect the order on `reflection_scope` if it exists, else use the natural order.
            if reflection_scope && !reflection_scope.order_values.empty?
              @id_map ||= id_to_index_map @preloaded_records
              rhs_records = rhs_records.sort_by { |rhs| @id_map[rhs] }
            end
            records_by_owner[lhs] = rhs_records
          end
        end

        private

          def id_to_index_map(ids)
            id_map = {}
            ids.each_with_index { |id, index| id_map[id] = index }
            id_map
          end

          def should_skip_setting_target?(owners, association_name, through_scope)
            (through_scope != through_reflection.klass.unscoped) ||
               (options[:source_type] && through_reflection.collection?)
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
