module ActiveRecord
  module Associations
    class Preloader
      class HasManyThrough < CollectionAssociation #:nodoc:
        include ThroughAssociation

        def associated_records_by_owner
          super.each_value do |records|
            records.uniq! if reflection_scope.distinct_value
          end
        end
      end
    end
  end
end
