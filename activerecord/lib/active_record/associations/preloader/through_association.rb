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

          Hash[owners.map do |owner|
            through_records = Array.wrap(owner.send(through_reflection.name))

            # Dont cache the association - we would only be caching a subset
            if reflection.options[:source_type] && through_reflection.collection?
              owner.association(through_reflection.name).reset
            end

            [owner, through_records]
          end]
        end

        def through_scope
          through_scope = through_reflection.klass.unscoped

          if options[:source_type]
            through_scope.where! reflection.foreign_type => options[:source_type]
          else
            unless reflection_scope.where_values.empty?
              through_scope.includes_values = reflection_scope.values[:includes] || options[:source]
              through_scope.where_values    = reflection_scope.values[:where]
            end

            through_scope.order!      reflection_scope.values[:order]
            through_scope.references! reflection_scope.values[:references]
          end

          through_scope
        end
      end
    end
  end
end
