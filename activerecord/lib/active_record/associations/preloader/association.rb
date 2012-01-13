module ActiveRecord
  module Associations
    class Preloader
      class Association #:nodoc:
        attr_reader :owners, :reflection, :preload_options, :model, :klass

        def initialize(klass, owners, reflection, preload_options)
          @klass           = klass
          @owners          = owners
          @reflection      = reflection
          @preload_options = preload_options || {}
          @model           = owners.first && owners.first.class
          @scoped          = nil
          @owners_by_key   = nil
        end

        def run
          unless owners.first.association(reflection.name).loaded?
            preload
          end
        end

        def preload
          raise NotImplementedError
        end

        def scoped
          @scoped ||= build_scope
        end

        def records_for(ids)
          scoped.where(association_key.in(ids))
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
            records = sliced.map { |slice| records_for(slice) }.flatten
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

        def build_scope
          scope = klass.scoped

          scope = scope.where(process_conditions(options[:conditions]))
          scope = scope.where(process_conditions(preload_options[:conditions]))

          scope = scope.select(preload_options[:select] || options[:select] || table[Arel.star])
          scope = scope.includes(preload_options[:include] || options[:include])

          if options[:as]
            scope = scope.where(
              klass.table_name => {
                reflection.type => model.base_class.sti_name
              }
            )
          end

          scope
        end

        def process_conditions(conditions)
          if conditions.respond_to?(:to_proc)
            conditions = klass.send(:instance_eval, &conditions)
          end

          if conditions
            klass.send(:sanitize_sql, conditions)
          end
        end
      end
    end
  end
end
