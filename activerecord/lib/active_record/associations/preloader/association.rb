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
          @scope         = nil
          @preloaded_records = []
        end

        def run(preloader)
          preload(preloader)
        end

        def preload(preloader)
          raise NotImplementedError
        end

        def scope
          @scope ||= build_scope
        end

        def records_for(ids)
          scope.where(association_key_name => ids)
        end

        def table
          klass.arel_table
        end

        # The name of the key on the associated records
        def association_key_name
          raise NotImplementedError
        end

        # This is overridden by HABTM as the condition should be on the foreign_key column in
        # the join table
        def association_key
          klass.arel_attribute(association_key_name, table)
        end

        # The name of the key on the model which declares the association
        def owner_key_name
          raise NotImplementedError
        end

        def options
          reflection.options
        end

        private

          def associated_records_by_owner(preloader)
            records = load_records do |record|
              owner = owners_by_key[convert_key(record[association_key_name])]
              association = owner.association(reflection.name)
              association.set_inverse_instance(record)
            end

            owners.each_with_object({}) do |owner, result|
              result[owner] = records[convert_key(owner[owner_key_name])] || []
            end
          end

          def owner_keys
            unless defined?(@owner_keys)
              @owner_keys = owners.map do |owner|
                owner[owner_key_name]
              end
              @owner_keys.uniq!
              @owner_keys.compact!
            end
            @owner_keys
          end

          def owners_by_key
            unless defined?(@owners_by_key)
              @owners_by_key = owners.each_with_object({}) do |owner, h|
                h[convert_key(owner[owner_key_name])] = owner
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
            @klass.type_for_attribute(association_key_name.to_s).type
          end

          def owner_key_type
            @model.type_for_attribute(owner_key_name.to_s).type
          end

          def load_records(&block)
            return {} if owner_keys.empty?
            # Some databases impose a limit on the number of ids in a list (in Oracle it's 1000)
            # Make several smaller queries if necessary or make one query if the adapter supports it
            slices = owner_keys.each_slice(klass.connection.in_clause_length || owner_keys.size)
            @preloaded_records = slices.flat_map do |slice|
              records_for(slice).load(&block)
            end
            @preloaded_records.group_by do |record|
              convert_key(record[association_key_name])
            end
          end

          def reflection_scope
            @reflection_scope ||= reflection.scope_for(klass)
          end

          def build_scope
            scope = klass.scope_for_association

            if reflection.type
              scope.where!(reflection.type => model.base_class.sti_name)
            end

            scope.merge!(reflection_scope)
            scope.merge!(preload_scope) if preload_scope != NULL_RELATION
            scope
          end
      end
    end
  end
end
