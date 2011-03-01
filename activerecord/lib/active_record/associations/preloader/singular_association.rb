module ActiveRecord
  module Associations
    class Preloader
      class SingularAssociation < Association #:nodoc:

        private

        def preload
          associated_records_by_owner.each do |owner, associated_records|
            record = associated_records.first

            association = owner.association(reflection.name)
            association.target = record
            association.set_inverse_instance(record)
          end
        end

      end
    end
  end
end
