module ActiveRecord
  module Associations
    class Preloader
      class HasManyThrough < CollectionAssociation #:nodoc:
        include ThroughAssociation

        def associated_records_by_owner
          super.each do |owner, records|
            records.uniq! if reflection_scope.uniq_value
          end
        end
      end
    end
  end
end
