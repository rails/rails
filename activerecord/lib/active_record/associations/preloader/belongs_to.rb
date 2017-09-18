# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class BelongsTo < SingularAssociation #:nodoc:
        def association_key_name
          options[:primary_key] || klass && klass.primary_key
        end
      end
    end
  end
end
