# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Association #:nodoc:
        attr_reader :owners, :reflection, :preload_scope, :model, :klass
        attr_reader :preloaded_records

        def initialize(klass, owners, reflection, preload_scope)
          @klass         = klass
          @owners        = owners
          @reflection    = reflection
          @preload_scope = preload_scope
          @model         = owners.first && owners.first.class
          @preloaded_records = []
        end

        def run(preloader)
          raise NotImplementedError
        end

        private
          def associate_records_to_owner(owner, records)
            association = owner.association(reflection.name)
            association.loaded!
            association.target = reflection.collection? ? records : records.first
          end

          def reflection_scope
            @reflection_scope ||= reflection.scope ? reflection.scope_for(klass.unscoped) : klass.unscoped
          end
      end
    end
  end
end
