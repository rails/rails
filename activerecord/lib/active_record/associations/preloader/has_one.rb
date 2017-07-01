module ActiveRecord
  module Associations
    class Preloader
      class HasOne < SingularAssociation #:nodoc:
        def association_key_name
          reflection.foreign_key
        end

        def owner_key_name
          reflection.active_record_primary_key
        end
      end
    end
  end
end
