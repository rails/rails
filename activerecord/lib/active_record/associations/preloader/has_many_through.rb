module ActiveRecord
  module Associations
    class Preloader
      class HasManyThrough < CollectionAssociation #:nodoc:
        include ThroughAssociation

        def associated_records_by_owner
          records_by_owner = super

          if reflection_scope.distinct_value
            records_by_owner.each_value { |records| records.uniq! }
          end

          records_by_owner
        end
      end
    end
  end
end
