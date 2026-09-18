# frozen_string_literal: true

# :enddoc:

module ActiveRecord
  module Associations
    class Preloader
      class Association # :nodoc:
        class LoaderQuery
          attr_reader :scope, :association_key_name

          def initialize(scope, association_key_name)
            @scope = scope
            @association_key_name = association_key_name
          end

          def eql?(other)
            association_key_name == other.association_key_name &&
              scope.table_name == other.scope.table_name &&
              scope.model.connection_specification_name == other.scope.model.connection_specification_name &&
              scope.values_for_queries == other.scope.values_for_queries
          end

          def hash
            [association_key_name, scope.model.table_name, scope.model.connection_specification_name, scope.values_for_queries].hash
          end

          def records_for(loaders)
            LoaderRecords.new(loaders, self).records
          end

          def load_records_in_batch(loaders)
            raw_records = records_for(loaders)

            loaders.each do |loader|
              loader.load_records(raw_records)
              loader.run
            end
          end

          def load_records_for_keys(keys, &block)
            return [] if keys.empty?

            filtered = apply_key_filter(keys)

            if ActiveRecord.respect_association_scope_limits &&
                (filtered.limit_value || filtered.offset_value)
              filtered = partition_by_owner(filtered, keys)
            end

            filtered.load(&block)
          end

          private
            def apply_key_filter(keys)
              scope.where(key_filter(keys))
            end

            def key_filter(keys)
              if association_key_name.is_a?(Array)
                query_constraints = Hash.new { |hsh, key| hsh[key] = Set.new }

                keys.each_with_object(query_constraints) do |values_set, constraints|
                  association_key_name.zip(values_set).each do |key_name, value|
                    constraints[key_name] << value
                  end
                end
              else
                { association_key_name => keys }
              end
            end

            def partition_by_owner(relation, keys)
              relation.model.with_connection do |connection|
                if connection.supports_lateral_joins?
                  partition_by_lateral(relation, keys)
                else
                  relation
                end
              end
            end

            def partition_by_lateral(relation, keys)
              model = relation.model
              table = model.arel_table
              key_names = Array(association_key_name)
              owners = Arel::Table.new(name: "__preload_owners")

              # A row per owner key to run the scope against, read off the key
              # column rather than built from the keys as a `VALUES` table.
              owner_keys = model.unscoped.distinct.select(*key_names).where(key_filter(keys))

              # Correlate on `scope`, not on the filtered relation: `unscope`ing
              # its `IN` filter would take the scope's own conditions on the key
              # column with it.
              inner = scope.where(
                key_names.map { |name| table[name].eq(owners[name]) }.inject(:and)
              )

              lateral = model.unscoped.from(owner_keys, owners.name)
                             .joins(Arel::Nodes::StringJoin.new(
                               Arel.sql("CROSS JOIN LATERAL (?) AS #{model.quoted_table_name}", inner.arel.ast)
                             ))
                             .select(table[Arel.star])

              orders = outer_orders(relation)
              orders.empty? ? lateral : lateral.order(*orders)
            end

            # The join is unordered, so the scope's order is repeated outside --
            # but only what the subquery projects can be named there. An order
            # left behind still picks the rows; only their order falls to the
            # database.
            def outer_orders(relation)
              orders = relation.arel.orders
              return [] unless orders.all? { |order| projected?(order, relation) }

              orders
            end

            def projected?(order, relation)
              order = order.expr if order.is_a?(Arel::Nodes::Ordering)
              return false unless order.is_a?(Arel::Attributes::Attribute)
              return false unless order.relation.name == relation.model.arel_table.name

              # Without a `select` every column comes back; with one, only a
              # column named plainly in it.
              relation.select_values.empty? || relation.select_values.any? do |value|
                (value.is_a?(Symbol) || value.is_a?(String)) && value.to_s == order.name.to_s
              end
            end
        end

        class LoaderRecords
          def initialize(loaders, loader_query)
            @loader_query = loader_query
            @loaders = loaders
            @keys_to_load = Set.new
            @already_loaded_records_by_key = {}

            populate_keys_to_load_and_already_loaded_records
          end

          def records
            load_records + already_loaded_records
          end

          private
            attr_reader :loader_query, :loaders, :keys_to_load, :already_loaded_records_by_key

            def populate_keys_to_load_and_already_loaded_records
              loaders.each do |loader|
                loader.owners_by_key.each do |key, owners|
                  if loaded_owner = owners.find { |owner| loader.loaded?(owner) }
                    already_loaded_records_by_key[key] = loader.target_for(loaded_owner)
                  else
                    keys_to_load << key
                  end
                end
              end

              @keys_to_load.subtract(already_loaded_records_by_key.keys)
            end

            def load_records
              loader_query.load_records_for_keys(keys_to_load) do |record|
                loaders.each { |l| l.set_inverse(record) }
              end
            end

            def already_loaded_records
              already_loaded_records_by_key.values.flatten
            end
        end

        attr_reader :klass

        def initialize(klass, owners, reflection, preload_scope, reflection_scope, associate_by_default)
          @klass         = klass
          @owners        = owners.uniq(&:__id__)
          @reflection    = reflection
          @preload_scope = preload_scope
          @reflection_scope = reflection_scope
          @associate     = associate_by_default || !preload_scope || preload_scope.empty_scope?
          @model         = owners.first && owners.first.class
          @run = false
        end

        def table_name
          @klass.table_name
        end

        def future_classes
          if run?
            []
          else
            [@klass]
          end
        end

        def runnable_loaders
          [self]
        end

        def run?
          @run
        end

        def run
          return self if run?
          @run = true

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

        # The name of the key on the associated records
        def association_key_name
          reflection.join_primary_key(klass)
        end

        def loader_query
          LoaderQuery.new(scope, association_key_name)
        end

        def owners_by_key
          @owners_by_key ||= owners.each_with_object({}) do |owner, result|
            key = derive_key(owner, owner_key_name)
            (result[key] ||= []) << owner if key.is_a?(Array) ? key.all? : key
          end
        end

        def loaded?(owner)
          owner.association(reflection.name).loaded?
        end

        def target_for(owner)
          Array.wrap(owner.association(reflection.name).target)
        end

        def scope
          @scope ||= build_scope
        end

        def set_inverse(record)
          if owners = owners_by_key[derive_key(record, association_key_name)]
            # Processing only the first owner
            # because the record is modified but not an owner
            association = owners.first.association(reflection.name)
            association.set_inverse_instance(record)
          end
        end

        def load_records(raw_records = nil)
          # owners can be duplicated when a relation has a collection association join
          # #compare_by_identity makes such owners different hash keys
          @records_by_owner = {}.compare_by_identity
          raw_records ||= loader_query.records_for([self])
          @preloaded_records = raw_records.select do |record|
            assignments = false

            owners_by_key[derive_key(record, association_key_name)]&.each do |owner|
              entries = (@records_by_owner[owner] ||= [])

              if reflection.collection? || entries.empty?
                entries << record
                assignments = true
              end
            end

            assignments
          end
        end

        def associate_records_from_unscoped(unscoped_records)
          return if unscoped_records.nil? || unscoped_records.empty?
          return if !reflection_scope.empty_scope?
          return if preload_scope && !preload_scope.empty_scope?
          return if reflection.collection?

          unscoped_records.select { |r| r[association_key_name].present? }.each do |record|
            owners = owners_by_key[derive_key(record, association_key_name)]
            owners&.each_with_index do |owner, i|
              association = owner.association(reflection.name)
              association.target = record

              if i == 0 # Set inverse on first owner
                association.set_inverse_instance(record)
              end
            end
          end
        end

        private
          attr_reader :owners, :reflection, :preload_scope, :model

          # The name of the key on the model which declares the association
          def owner_key_name
            reflection.join_foreign_key
          end

          def associate_records_to_owner(owner, records)
            return if loaded?(owner)

            association = owner.association(reflection.name)

            if reflection.collection?
              not_persisted_records = association.target.reject(&:persisted?)
              association.target = records + not_persisted_records
            else
              association.target = records.first
            end
          end

          def key_conversion_required?
            unless defined?(@key_conversion_required)
              @key_conversion_required = (association_key_type != owner_key_type)
            end

            @key_conversion_required
          end

          def derive_key(owner, key)
            if key.is_a?(Array)
              key.map { |k| convert_key(owner.read_attribute(k)) }
            else
              convert_key(owner.read_attribute(key))
            end
          end

          def convert_key(key)
            if key_conversion_required?
              key&.to_s
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

            cascade_strict_loading(scope)
          end

          def cascade_strict_loading(scope)
            preload_scope&.strict_loading_value ? scope.strict_loading : scope
          end
      end
    end
  end
end
