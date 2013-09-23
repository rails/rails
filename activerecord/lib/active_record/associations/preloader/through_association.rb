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
          @loaded = true

          return @associated_records_by_owner if @associated_records_by_owner

          left_loader = Preloader.new(owners,
                                      through_reflection.name,
                                      through_scope)
          left_loader.run

          should_reset = (through_scope != through_reflection.klass.unscoped) ||
             (reflection.options[:source_type] && through_reflection.collection?)

          through_records = owners.map do |owner, h|
            association = owner.association through_reflection.name

            x = [owner, Array(association.reader)]

            # Dont cache the association - we would only be caching a subset
            association.reset if should_reset

            x
          end

          middle_records = through_records.map { |(_,rec)| rec }.flatten

          preloader = Preloader.new(middle_records,
                                    source_reflection.name,
                                    reflection_scope)

          preloader.run

          middle_to_pl = preloader.preloaders.each_with_object({}) do |pl,h|
            pl.owners.each { |middle|
              h[middle] = pl
            }
          end

          @associated_records_by_owner = through_records.each_with_object({}) { |(lhs,middles),h|
            preloader = middle_to_pl[middles.first]

            rhs_records = middles.flat_map { |r|
              r.send(source_reflection.name)
            }.compact

            if preloader && preloader.loaded?
              loaded_records = preloader.preloaded_records
              i = 0
              record_index = loaded_records.each_with_object({}) { |r,indexes|
                indexes[r] = i
                i += 1
              }
              rs = rhs_records.sort_by { |rhs| record_index[rhs] }
            else
              rs = rhs_records
            end

            h[lhs] = rs
          }
        end

        private

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
