module ActiveRecord
  module Associations
    class Preloader
      class Association #:nodoc:
        attr_reader :owners, :reflection, :preload_scope, :model, :klass

        def initialize(klass, owners, reflection, preload_scope)
          @klass         = klass
          @owners        = owners
          @reflection    = reflection
          @preload_scope = preload_scope
          @model         = owners.first && owners.first.class
          @scope         = nil
          @owners_by_key = nil
        end

        def run
          unless owners.first.association(reflection.name).loaded?
            preload
          end
        end

        def preload
          raise NotImplementedError
        end

        def scope
          @scope ||= build_scope
        end

        def records_for(ids)
          scope.where(association_key.in(ids))
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
          table[association_key_name]
        end

        # The name of the key on the model which declares the association
        def owner_key_name
          raise NotImplementedError
        end

        # We're converting to a string here because postgres will return the aliased association
        # key in a habtm as a string (for whatever reason)
        def owners_by_key
          @owners_by_key ||= owners.group_by do |owner|
            key = owner[owner_key_name]
            key && key.to_s
          end
        end

        def options
          reflection.options
        end

        private

        def associated_records_by_owner
          owners_map = owners_by_key
          owner_keys = owners_map.keys.compact

          if klass.nil? || owner_keys.empty?
            records = []
          else
            # Some databases impose a limit on the number of ids in a list (in Oracle it's 1000)
            # Make several smaller queries if necessary or make one query if the adapter supports it
            sliced  = owner_keys.each_slice(model.connection.in_clause_length || owner_keys.size)
            records = sliced.map { |slice| records_for(slice).to_a }.flatten
          end

          # Each record may have multiple owners, and vice-versa
          records_by_owner = Hash[owners.map { |owner| [owner, []] }]
          records.each do |record|
            owner_key = record[association_key_name].to_s

            owners_map[owner_key].each do |owner|
              records_by_owner[owner] << record
            end
          end
          records_by_owner
        end

        def reflection_scope
          @reflection_scope ||= reflection.scope ? klass.unscoped.instance_exec(nil, &reflection.scope) : klass.unscoped
        end

        def build_scope
          scope = klass.unscoped
          scope.default_scoped = true

          values         = reflection_scope.values
          preload_values = preload_scope.values

          scope.where_values      = Array(values[:where])      + Array(preload_values[:where])
          scope.references_values = Array(values[:references]) + Array(preload_values[:references])

          scope.select!   preload_values[:select] || values[:select] || table[Arel.star]
          scope.includes! preload_values[:includes] || values[:includes]

          if options[:as]
            scope.where!(klass.table_name => { reflection.type => model.base_class.sti_name })
          end

          scope
        end
      end
    end
  end
end
