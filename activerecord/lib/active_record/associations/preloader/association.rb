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
          @owners_by_key = nil
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
          query_scope(ids)
        end

        def query_scope(ids)
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

        def owners_by_key
          @owners_by_key ||= if key_conversion_required?
                               owners.group_by do |owner|
                                 owner[owner_key_name].to_s
                               end
                             else
                               owners.group_by do |owner|
                                 owner[owner_key_name]
                               end
                             end
        end

        def options
          reflection.options
        end

        private

        def associated_records_by_owner(preloader)
          owners_map = owners_by_key
          owner_keys = owners_map.keys.compact

          # Each record may have multiple owners, and vice-versa
          records_by_owner = owners.each_with_object({}) do |owner,h|
            h[owner] = []
          end

          if owner_keys.any?
            # Some databases impose a limit on the number of ids in a list (in Oracle it's 1000)
            # Make several smaller queries if necessary or make one query if the adapter supports it
            sliced  = owner_keys.each_slice(klass.connection.in_clause_length || owner_keys.size)

            records = load_slices sliced
            records.each do |record, owner_key|
              owners_map[owner_key].each do |owner|
                records_by_owner[owner] << record
              end
            end
          end

          records_by_owner
        end

        def key_conversion_required?
          association_key_type != owner_key_type
        end

        def association_key_type
          column = @klass.column_types[association_key_name.to_s]
          column && column.type
        end

        def owner_key_type
          column = @model.column_types[owner_key_name.to_s]
          column && column.type
        end

        def load_slices(slices)
          @preloaded_records = slices.flat_map { |slice|
            records_for(slice)
          }

          @preloaded_records.map { |record|
            key = record[association_key_name]
            key = key.to_s if key_conversion_required?

            [record, key]
          }
        end

        def reflection_scope
          @reflection_scope ||= reflection.scope ? klass.unscoped.instance_exec(nil, &reflection.scope) : klass.unscoped
        end

        def build_scope
          scope = klass.unscoped

          values         = reflection_scope.values
          preload_values = preload_scope.values

          scope.where_values      = Array(values[:where])      + Array(preload_values[:where])
          scope.references_values = Array(values[:references]) + Array(preload_values[:references])

          scope._select!   preload_values[:select] || values[:select] || table[Arel.star]
          scope.includes! preload_values[:includes] || values[:includes]

          if preload_values.key? :order
            scope.order! preload_values[:order]
          else
            if values.key? :order
              scope.order! values[:order]
            end
          end

          if options[:as]
            scope.where!(klass.table_name => { reflection.type => model.base_class.sti_name })
          end

          scope.unscope_values = Array(values[:unscope])
          klass.default_scoped.merge(scope)
        end
      end
    end
  end
end
