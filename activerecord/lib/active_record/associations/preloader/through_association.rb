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
          preloader.preload(owners,
                            through_reflection.name,
                            through_scope)

          through_records = owners.map do |owner|
            association = owner.association through_reflection.name

            center = target_records_from_association(association)
            [owner, Array(center)]
          end

          reset_association owners, through_reflection.name

          middle_records = through_records.flat_map { |(_,rec)| rec }

          preloaders = preloader.preload(middle_records,
                                         source_reflection.name,
                                         reflection_scope)

          @preloaded_records = preloaders.flat_map(&:preloaded_records)

          middle_to_pl = preloaders.each_with_object({}) do |pl,h|
            pl.owners.each { |middle|
              h[middle] = pl
            }
          end

          record_offset = {}
          @preloaded_records.each_with_index do |record,i|
            record_offset[record] = i
          end

          through_records.each_with_object({}) { |(lhs,center),records_by_owner|
            pl_to_middle = center.group_by { |record| middle_to_pl[record] }

            records_by_owner[lhs] = pl_to_middle.flat_map do |pl, middles|
              rhs_records = middles.flat_map { |r|
                association = r.association source_reflection.name

                target_records_from_association(association)
              }.compact

              rhs_records.sort_by { |rhs| record_offset[rhs] }
            end
          }
        end

        private

        def reset_association(owners, association_name)
          should_reset = (through_scope != through_reflection.klass.unscoped) ||
             (reflection.options[:source_type] && through_reflection.collection?)

          # Don't cache the association - we would only be caching a subset
          if should_reset
            owners.each { |owner|
              owner.association(association_name).reset
            }
          end
        end


        def through_scope
          scope = through_reflection.klass.unscoped

          if options[:source_type]
            scope.where! reflection.foreign_type => options[:source_type]
          else
            references_value = filter_reflection_scope(:references, scope)

            if !reflection_scope.where_clause.empty? && references_value && references_value.any?
              scope.includes_values = Array(filter_reflection_scope(:includes, scope) || options[:source])
              scope.where_clause = reflection_scope.where_clause
            end

            scope.references! reflection_scope.values[:references]
            if scope.eager_loading? && order_values = reflection_scope.values[:order]
              scope = scope.order(order_values)
            end
          end

          scope
        end

        def filter_reflection_scope(type, scope)
          return unless reflection_scope.values[type]
          ignored_tables = [reflection_scope.table.name.to_s, scope.table.name]
          reflection_scope.values[type].select do |reference_name|
            ignored_tables.include?(reference_name.to_s)
          end
        end

        def target_records_from_association(association)
          association.loaded? ? association.target : association.reader
        end
      end
    end
  end
end
