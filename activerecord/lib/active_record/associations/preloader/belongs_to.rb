module ActiveRecord
  module Associations
    class Preloader
      class BelongsTo < SingularAssociation #:nodoc:

        def association_key_name
          reflection.options[:primary_key] || klass && klass.primary_key
        end

        def owner_key_name
          reflection.foreign_key
        end

      end
    end
  end
end
