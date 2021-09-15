# frozen_string_literal: true

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
              scope.values_for_queries == other.scope.values_for_queries
          end

          def hash
            [association_key_name, scope.table_name, scope.values_for_queries].hash
          end

          def records_for(loaders)
            ids = loaders.flat_map(&:owner_keys).uniq

            scope.where(association_key_name => ids).load do |record|
              loaders.each { |l| l.set_inverse(record) }
            end
          end

          def load_records_in_batch(loaders)
            raw_records = records_for(loaders)

            loaders.each do |loader|
              loader.load_records(raw_records)
              loader.run
            end
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

        def data_available?
          already_loaded?
        end

        def future_classes
          if run? || already_loaded?
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

          if already_loaded?
            fetch_from_preloaded_records
            return self
          end

          records = records_by_owner

          owners.each do |owner|
            associate_records_to_owner(owner, records[owner] || [])
          end if @associate

          self
        end

        def records_by_owner
          ensure_loaded unless defined?(@records_by_owner)

          @records_by_owner
        end

        def preloaded_records
          ensure_loaded unless defined?(@preloaded_records)

          @preloaded_records
        end

        def ensure_loaded
          if already_loaded?
            fetch_from_preloaded_records
          else
            load_records
          end
        end

        # The name of the key on the associated records
        def association_key_name
          reflection.join_primary_key(klass)
        end

        def loader_query
          LoaderQuery.new(scope, association_key_name)
        end

        def owner_keys
          @owner_keys ||= owners_by_key.keys
        end

        def scope
          @scope ||= build_scope
        end

        def set_inverse(record)
          if owners = owners_by_key[convert_key(record[association_key_name])]
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

            owners_by_key[convert_key(record[association_key_name])]&.each do |owner|
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

          unscoped_records.each do |record|
            owners = owners_by_key[convert_key(record[association_key_name])]
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

          def already_loaded?
            @already_loaded ||= owners.all? { |o| o.association(reflection.name).loaded? }
          end

          def fetch_from_preloaded_records
            @records_by_owner = owners.index_with do |owner|
              Array(owner.association(reflection.name).target)
            end

            @preloaded_records = records_by_owner.flat_map(&:last)
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

          def reflection_scope
            @reflection_scope ||= reflection.join_scopes(klass.arel_table, klass.predicate_builder, klass).inject(&:merge!) || klass.unscoped
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
