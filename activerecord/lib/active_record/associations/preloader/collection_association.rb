# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class CollectionAssociation < Association #:nodoc:
        private
          def associate_records_to_owner(owner, records)
            association = owner.association(reflection.name)
            association.loaded!
            association.target.concat(records)
          end
      end
    end
  end
end
