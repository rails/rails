# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class Association #:nodoc:
        def initialize(klass, owners, reflection, preload_scope, associate_by_default = true)
          @klass         = klass
          @owners        = owners.uniq(&:__id__)
          @reflection    = reflection
          @preload_scope = preload_scope
          @associate     = associate_by_default || !preload_scope || preload_scope.empty_scope?
          @model         = owners.first && owners.first.class
        end

        def run
          records = records_by_owner

          owners.each do |owner|
            associate_records_to_owner(owner, records[owner] || [])
          end if @associate

          self
        end

        def records_by_owner
          load_records unless defined?(@records_by_owner)

          @records_by_owner
        end

        def preloaded_records
          load_records unless defined?(@preloaded_records)

          @preloaded_records
        end

        private
          attr_reader :owners, :reflection, :preload_scope, :model, :klass

          def load_records
            # owners can be duplicated when a relation has a collection association join
            # #compare_by_identity makes such owners different hash keys
            @records_by_owner = {}.compare_by_identity
            raw_records = owner_keys.empty? ? [] : records_for(owner_keys)

            @preloaded_records = raw_records.select do |record|
              assignments = false

              owners_by_key[convert_key(record[association_key_name])].each do |owner|
                entries = (@records_by_owner[owner] ||= [])

                if reflection.collection? || entries.empty?
                  entries << record
                  assignments = true
                end
              end

              assignments
            end
          end

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
            if reflection.collection?
              association.target = records
            else
              association.target = records.first
            end
          end

          def owner_keys
            @owner_keys ||= owners_by_key.keys
          end

          def owners_by_key
            @owners_by_key ||= owners.each_with_object({}) do |owner, result|
              key = convert_key(owner[owner_key_name])
              (result[key] ||= []) << owner if key
            end
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

          def records_for(ids)
            scope.where(association_key_name => ids).load do |record|
              # Processing only the first owner
              # because the record is modified but not an owner
              owner = owners_by_key[convert_key(record[association_key_name])].first
              association = owner.association(reflection.name)
              association.set_inverse_instance(record)
            end
          end

          def scope
            @scope ||= build_scope
          end

          def reflection_scope
            @reflection_scope ||= reflection.join_scopes(klass.arel_table, klass.predicate_builder, klass).inject(klass.unscoped, &:merge!)
          end

          def build_scope
            scope = klass.scope_for_association

            if reflection.type && !reflection.through_reflection?
              scope.where!(reflection.type => model.polymorphic_name)
            end

            scope.merge!(reflection_scope) unless reflection_scope.empty_scope?

            if preload_scope && !preload_scope.empty_scope?
              scope.merge!(preload_scope)
            end

            if preload_scope && preload_scope.strict_loading_value
              scope.strict_loading
            else
              scope
            end
          end
      end
    end
  end
end
