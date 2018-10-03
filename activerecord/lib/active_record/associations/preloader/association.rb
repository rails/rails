# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Association #:nodoc:
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
          records = load_records do |record|
            owner = owners_by_key[convert_key(record[association_key_name])]
            association = owner.association(reflection.name)
            association.set_inverse_instance(record)
          end

          owners.each do |owner|
            associate_records_to_owner(owner, records[convert_key(owner[owner_key_name])] || [])
          end
        end

        private
          attr_reader :owners, :reflection, :preload_scope, :model, :klass

          # The name of the key on the associated records
          def association_key_name
            reflection.join_primary_key(klass)
          end

          # The name of the key on the model which declares the association
          def owner_key_name
            reflection.join_foreign_key
          end

          def associate_records_to_owner(owner, records)
            association = owner.association(reflection.name)
            association.loaded!
            if reflection.collection?
              association.target.concat(records)
            else
              association.target = records.first unless records.empty?
            end
          end

          def owner_keys
            @owner_keys ||= owners_by_key.keys
          end

          def owners_by_key
            unless defined?(@owners_by_key)
              @owners_by_key = owners.each_with_object({}) do |owner, h|
                key = convert_key(owner[owner_key_name])
                h[key] = owner if key
              end
            end
            @owners_by_key
          end

          def key_conversion_required?
            unless defined?(@key_conversion_required)
              @key_conversion_required = (association_key_type != owner_key_type)
            end

            @key_conversion_required
          end

          def convert_key(key)
            if key_conversion_required?
              key.to_s
            else
              key
            end
          end

          def association_key_type
            @klass.type_for_attribute(association_key_name).type
          end

          def owner_key_type
            @model.type_for_attribute(owner_key_name).type
          end

          def load_records(&block)
            return {} if owner_keys.empty?
            # Some databases impose a limit on the number of ids in a list (in Oracle it's 1000)
            # Make several smaller queries if necessary or make one query if the adapter supports it
            slices = owner_keys.each_slice(klass.connection.in_clause_length || owner_keys.size)
            @preloaded_records = slices.flat_map do |slice|
              if scope.limit_value
                slice.flat_map { |owner_key| records_for(owner_key, &block) }
              else
                records_for(slice, &block)
              end
            end
            @preloaded_records.group_by do |record|
              convert_key(record[association_key_name])
            end
          end

          def records_for(ids, &block)
            scope.where(association_key_name => ids).load(&block)
          end

          def scope
            @scope ||= build_scope
          end

          def reflection_scope
            @reflection_scope ||= reflection.scope ? reflection.scope_for(klass.unscoped) : klass.unscoped
          end

          def build_scope
            scope = klass.scope_for_association

            if reflection.type
              scope.where!(reflection.type => model.polymorphic_name)
            end

            scope.merge!(reflection_scope) if reflection.scope
            scope.merge!(preload_scope) if preload_scope
            scope
          end
      end
    end
  end
end
