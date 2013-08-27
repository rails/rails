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

        def associated_records_by_owner
          through_records = through_records_by_owner

          Preloader.new(through_records.values.flatten, source_reflection.name, reflection_scope).run

          through_records.each do |owner, records|
            records.map! { |r| r.send(source_reflection.name) }.flatten!
            records.compact!
          end
        end

        private

        def through_records_by_owner
          Preloader.new(owners, through_reflection.name, through_scope).run

          should_reset = (through_scope != through_reflection.klass.unscoped) ||
             (reflection.options[:source_type] && through_reflection.collection?)

          owners.each_with_object({}) do |owner, h|
            association = owner.association through_reflection.name
            through_records = Array(association.reader)

            # Dont cache the association - we would only be caching a subset
            association.reset if should_reset

            h[owner] = through_records
          end
        end

        def through_scope
          scope = through_reflection.klass.unscoped

          if options[:source_type]
            scope.where! reflection.foreign_type => options[:source_type]
          else
            unless reflection_scope.where_values.empty?
              scope.includes_values = Array(reflection_scope.values[:includes] || options[:source])
              scope.where_values    = reflection_scope.values[:where]
            end

            scope.references! reflection_scope.values[:references]
            scope.order! reflection_scope.values[:order] if scope.eager_loading?
          end

          scope
        end
      end
    end
  end
end
