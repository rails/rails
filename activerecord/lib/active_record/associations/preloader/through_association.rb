# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class ThroughAssociation < Association # :nodoc:
        def run(preloader)
          already_loaded     = owners.first.association(through_reflection.name).loaded?
          through_scope      = through_scope()
          through_preloaders = preloader.preload(owners, through_reflection.name, through_scope)
          middle_records     = through_preloaders.flat_map(&:preloaded_records)
          preloaders         = preloader.preload(middle_records, source_reflection.name, scope)
          @preloaded_records = preloaders.flat_map(&:preloaded_records)

          owners.each do |owner|
            through_records = Array(owner.association(through_reflection.name).target)

            if already_loaded
              if source_type = reflection.options[:source_type]
                through_records = through_records.select do |record|
                  record[reflection.foreign_type] == source_type
                end
              end
            else
              owner.association(through_reflection.name).reset if through_scope
            end

            result = through_records.flat_map do |record|
              record.association(source_reflection.name).target
            end

            result.compact!
            result.sort_by! { |rhs| preload_index[rhs] } if scope.order_values.any?
            result.uniq! if scope.distinct_value
            associate_records_to_owner(owner, result)
          end

          unless scope.empty_scope?
            middle_records.each do |owner|
              owner.association(source_reflection.name).reset if owner
            end
          end
        end

        private
          def through_reflection
            reflection.through_reflection
          end

          def source_reflection
            reflection.source_reflection
          end

          def preload_index
            @preload_index ||= @preloaded_records.each_with_object({}).with_index do |(id, result), index|
              result[id] = index
            end
          end

          def through_scope
            scope = through_reflection.klass.unscoped
            options = reflection.options

            values = reflection_scope.values
            if annotations = values[:annotate]
              scope.annotate!(*annotations)
            end

            if options[:source_type]
              scope.where! reflection.foreign_type => options[:source_type]
            elsif !reflection_scope.where_clause.empty?
              scope.where_clause = reflection_scope.where_clause

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
