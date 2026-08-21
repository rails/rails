# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Association
    class BelongsToAssociation < SingularAssociation # :nodoc:
      attr_reader :foreign_key, :foreign_type

      def initialize(owner, reflection)
        super
        aliases = owner.class.attribute_aliases
        fk = reflection.foreign_key
        resolved_fk = fk.is_a?(Array) ? fk.map { |k| aliases[k] || k } : (aliases[fk] || fk)
        @foreign_key = ActiveRecord::Key.for(resolved_fk)
        if reflection.polymorphic?
          ft = reflection.foreign_type
          @foreign_type = aliases[ft] || ft
        end
      end

      def handle_dependency
        return unless load_target

        case options[:dependent]
        when :destroy
          raise ActiveRecord::Rollback unless target.destroy
        when :destroy_async
          association_class = if reflection.polymorphic?
            target.class
          else
            reflection.klass
          end

          primary_key_column = reflection.query_primary_key(association_class)
          query_foreign_key = ActiveRecord::Key.for(reflection.query_foreign_key)
          ids = query_foreign_key.map { |column| owner.public_send(column) }

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: association_class.to_s,
            association_ids: query_foreign_key.composite? ? [ids] : ids,
            association_primary_key_column: primary_key_column,
            ensuring_owner_was_method: options.fetch(:ensuring_owner_was, nil)
          )
        else
          target.public_send(options[:dependent])
        end
      end

      def inversed_from(record)
        replace_keys(record)
        super
      end

      def default(&block)
        writer(owner.instance_exec(&block)) if reader.nil?
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      def decrement_counters
        update_counters(-1)
      end

      def increment_counters
        update_counters(1)
      end

      def decrement_counters_before_last_save
        if reflection.polymorphic?
          model_type_was = owner.attribute_before_last_save(foreign_type)
          model_was = owner.class.polymorphic_class_for(model_type_was) if model_type_was
        else
          model_was = klass
        end

        values = foreign_key.map { |fk| owner.attribute_before_last_save(fk) }
        foreign_key_was = foreign_key.composite? ? (values if values.all?) : values.first

        if foreign_key_was && model_was < ActiveRecord::Base
          update_counters_via_scope(model_was, foreign_key_was, -1)
        end
      end

      def target_changed?
        foreign_key.any? { |fk| owner.attribute_changed?(fk) } || (!foreign_key_present? && target&.new_record?)
      end

      def target_previously_changed?
        foreign_key.any? { |fk| owner.attribute_previously_changed?(fk) }
      end

      def saved_change_to_target?
        foreign_key.any? { |fk| owner.saved_change_to_attribute?(fk) }
      end

      private
        def replace(record)
          if record
            raise_on_type_mismatch!(record)
            set_inverse_instance(record)
            @updated = true
          elsif target
            remove_inverse_instance(target)
          end

          replace_keys(record, force: true)

          self.target = record
        end

        def update_counters(by)
          if require_counter_update? && foreign_key_present?
            if target && !stale_target?
              target.increment!(reflection.counter_cache_column, by, touch: reflection.options[:touch])
            else
              update_counters_via_scope(klass, foreign_key.value_of(owner), by)
            end
          end
        end

        def update_counters_via_scope(klass, values, by)
          primary_key = ActiveRecord::Key.for(primary_key(klass))
          scope = klass.all_queries_scope.where!(primary_key.where_hash(values))
          scope.update_counters(reflection.counter_cache_column => by, touch: reflection.options[:touch])
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def replace_keys(record, force: false)
          target_key = if record
            reflection.query_key_mapping(record.class).foreign_key_associated_record_columns
          end
          target_key = ActiveRecord::Key.for(target_key)

          target_key_values = target_key.map { |key| record.read_attribute(key) }
          owner_key_values = foreign_key.map { |fk| owner.read_attribute(fk) }

          return if !force && owner_key_values == target_key_values

          owner_pk = ActiveRecord::Key.for(owner.class.primary_key)

          # Preserve shared primary key columns only if another foreign key
          # column can be cleared to disassociate the record.
          preserve_owner_pk = record.nil? && foreign_key.any? { |key| !owner_pk.include?(key) }

          foreign_key.each_with_index do |key, index|
            next if preserve_owner_pk && owner_pk.include?(key)
            owner.write_attribute(key, target_key_values[index])
          end
        end

        def primary_key(klass)
          reflection.association_primary_key(klass)
        end

        def foreign_key_present?
          foreign_key.all? { |fk| owner.read_attribute(fk) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          keys = if reflection.options[:query_constraints]
            reflection.foreign_key
          else
            reflection.query_foreign_key
          end
          key = ActiveRecord::Key.for(keys)
          values = key.map do |column|
            owner.read_attribute(column) { |name| owner.send(:missing_attribute, name, caller) }
          end
          key.composite? ? (values if values.any?) : values.first
        end
    end
  end
end
