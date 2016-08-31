module ActiveRecord
  module Associations
    class Preloader
      class CollectionAssociation < Association #:nodoc:
        private

        def preload(preloader)
          associated_records_by_owner(preloader).each do |owner, records|
            association = owner.association(reflection.name)
            association.loaded!
            association.target.concat(records)
          end
        end
      end
    end
  end
end
