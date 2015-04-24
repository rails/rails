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

        private

        def build_scope
          order = preload_scope.values[:order] || reflection_scope.values[:order]
          order ? super.order(order) : super
        end

      end
    end
  end
end
