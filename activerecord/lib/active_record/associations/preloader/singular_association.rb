# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class SingularAssociation < Association #:nodoc:
        private
          def associate_records_to_owner(owner, records)
            association = owner.association(reflection.name)
            association.target = records.first
          end
      end
    end
  end
end
