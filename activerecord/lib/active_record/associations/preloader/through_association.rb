# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class ThroughAssociation < Association # :nodoc:
        def preloaded_records
          @preloaded_records ||= source_preloaders.flat_map(&:preloaded_records)
        end

        def records_by_owner
          return @records_by_owner if defined?(@records_by_owner)
          source_records_by_owner = source_preloaders.map(&:records_by_owner).reduce(:merge)
          through_records_by_owner = through_preloaders.map(&:records_by_owner).reduce(:merge)

          @records_by_owner = owners.each_with_object({}) do |owner, result|
            through_records = through_records_by_owner[owner] || []

            if owners.first.association(through_reflection.name).loaded?
              if source_type = reflection.options[:source_type]
                through_records = through_records.select do |record|
                  record[reflection.foreign_type] == source_type
                end
              end
            end

            records = through_records.flat_map do |record|
              source_records_by_owner[record]
            end

            records.compact!
            records.sort_by! { |rhs| preload_index[rhs] } if scope.order_values.any?
            records.uniq! if scope.distinct_value
            result[owner] = records
          end
        end

        private
          def source_preloaders
            @source_preloaders ||= ActiveRecord::Associations::Preloader.new(records: middle_records, associations: source_reflection.name, scope: scope, associate_by_default: false).call
          end

          def middle_records
            through_preloaders.flat_map(&:preloaded_records)
          end

          def through_preloaders
            @through_preloaders ||= ActiveRecord::Associations::Preloader.new(records: owners, associations: through_reflection.name, scope: through_scope, associate_by_default: false).call
          end

          def through_reflection
            reflection.through_reflection
          end

          def source_reflection
            reflection.source_reflection
          end

          def preload_index
            @preload_index ||= preloaded_records.each_with_object({}).with_index do |(record, result), index|
              result[record] = index
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
                scope.references_values |= values[:references]
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

            scope
          end
      end
    end
  end
end
