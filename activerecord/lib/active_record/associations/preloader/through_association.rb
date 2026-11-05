# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class ThroughAssociation < Association # :nodoc:
        EMPTY_FIXED_VALUES = {}.freeze
        private_constant :EMPTY_FIXED_VALUES

        def self.association_route_for(*)
        end

        def associate_records_from_unscoped(*)
        end

        def preloaded_records
          @preloaded_records ||= source_preloaders.flat_map(&:preloaded_records)
        end

        def records_by_owner
          @records_by_owner ||= owners.each_with_object({}) do |owner, result|
            if loaded?(owner)
              result[owner] = target_for(owner)
              next
            end

            through_records = filter_by_source_type(through_records_by_owner[owner] || [])

            records = through_records.flat_map do |record|
              source_records_by_owner[record]
            end

            records.compact!
            records.sort_by! { |rhs| preload_index[rhs] } if source_order_applies?
            records.uniq! if scope.distinct_value
            result[owner] = records
          end
        end

        def runnable_loaders
          if data_available?
            [self]
          elsif through_preloaders.all?(&:run?)
            source_preloaders.flat_map(&:runnable_loaders)
          else
            through_preloaders.flat_map(&:runnable_loaders)
          end
        end

        def future_classes
          if run?
            []
          elsif through_preloaders.all?(&:run?)
            source_preloaders.flat_map(&:future_classes).uniq
          else
            through_classes = through_preloaders.flat_map(&:future_classes)
            source_classes = source_reflection.
              chain.
              reject { |reflection| reflection.respond_to?(:polymorphic?) && reflection.polymorphic? }.
              map(&:klass)
            (through_classes + source_classes).uniq
          end
        end

        private
          def destination_fixed_values
            EMPTY_FIXED_VALUES
          end

          def data_available?
            owners.all? { |owner| loaded?(owner) } ||
              through_preloaders.all?(&:run?) && source_preloaders.all?(&:run?)
          end

          def source_preloaders
            @source_preloaders ||= ActiveRecord::Associations::Preloader.new(records: middle_records, associations: source_reflection.name, scope: scope, associate_by_default: false).loaders.tap do |loaders|
              loaders.each(&:ignore_loaded_target!) if source_scope_filters_source?
            end
          end

          def middle_records
            filter_by_source_type(through_records_by_owner.values.flatten)
          end

          # Already loaded through records aren't filtered by `source_type`.
          def filter_by_source_type(through_records)
            if source_type = reflection.options[:source_type]
              source_type = source_type.to_s
              through_records.select do |record|
                record.read_attr(reflection.foreign_type) == source_type
              end
            else
              through_records
            end
          end

          def through_preloaders
            @through_preloaders ||= ActiveRecord::Associations::Preloader.new(records: owners, associations: through_reflection.name, scope: through_scope, associate_by_default: false).loaders.tap do |loaders|
              loaders.each(&:ignore_loaded_target!) if through_scope_filters_source?
            end
          end

          def through_reflection
            reflection.through_reflection
          end

          def source_reflection
            reflection.source_reflection
          end

          def source_records_by_owner
            @source_records_by_owner ||= source_preloaders.map(&:records_by_owner).reduce(:merge)
          end

          def through_records_by_owner
            @through_records_by_owner ||= through_preloaders.map(&:records_by_owner).reduce(:merge)
          end

          def preload_index
            @preload_index ||= preloaded_records.each_with_object({}).with_index do |(record, result), index|
              result[record] = index
            end
          end

          def through_scope_filters_source?
            !reflection.options[:disable_joins] &&
              through_reflection.klass.table_name != klass.table_name &&
              !reflection_scope.where_clause.empty?
          end

          # When the through scope doesn't eager load the source records with the
          # conditions or the order, the source scope filters or sorts them instead.
          def source_scope_filters_source?
            !through_scope_filters_source? &&
              (!reflection_scope.where_clause.empty? || !reflection_scope.effective_order_values.empty?)
          end

          # As in SQL, an explicit order on the through association beats the
          # default order of the source.
          def source_order_applies?
            return @source_order_applies if defined?(@source_order_applies)

            @source_order_applies = scope.order_values.any? ||
              (!scope.effective_order_values.empty? &&
                through_preloaders.none? { |loader| loader.scope.order_values.any? })
          end

          def through_scope
            scope = through_reflection.klass.unscoped
            options = reflection.options

            return scope if options[:disable_joins]

            values = reflection_scope.values
            if annotations = values[:annotate]
              scope.annotate!(*annotations)
            end

            if options[:source_type]
              scope.where! reflection.foreign_type => options[:source_type]
            end

            if through_scope_filters_source?
              scope.where_clause += reflection_scope.where_clause

              includes = values[:includes]

              # The class fixed by `source_type` can't be preloaded, only eager loaded.
              if source_type_reflection = reflection.source_type_reflection
                source = source_type_reflection
                scope.eager_load!(includes ? { source => includes } : source)
              else
                source = source_reflection.name
                scope.includes!(includes ? { source => includes } : source)
              end

              if values[:references] && !values[:references].empty?
                scope.references_values |= values[:references]
              else
                scope.references!((source_type_reflection || source_reflection).table_name)
              end

              if joins = values[:joins]
                scope.joins!(source => joins)
              end

              if left_outer_joins = values[:left_outer_joins]
                scope.left_outer_joins!(source => left_outer_joins)
              end

              # Both are kept so that `effective_order_values` picks one as for the source.
              if scope.eager_loading?
                scope.order_values = reflection_scope.order_values
                scope.default_order_values = reflection_scope.default_order_values
              end
            end

            cascade_strict_loading(scope)
          end
      end
    end
  end
end
