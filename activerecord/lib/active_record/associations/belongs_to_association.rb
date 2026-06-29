# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Belongs To Association
    class BelongsToAssociation < SingularAssociation # :nodoc:
      def handle_dependency
        return unless load_target

        case options[:dependent]
        when :destroy
          raise ActiveRecord::Rollback unless target.destroy
        when :destroy_async
          primary_key_column = reflection.active_record_primary_key
          ids = foreign_keys.map { |col| owner.public_send(col) }

          association_class = if reflection.polymorphic?
            owner.public_send(reflection.foreign_type)
          else
            reflection.klass
          end

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: association_class.to_s,
            association_ids: [ids],
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
          model_type_was = owner.attribute_before_last_save(reflection.foreign_type)
          model_was = owner.class.polymorphic_class_for(model_type_was) if model_type_was
        else
          model_was = klass
        end

        foreign_key_was = foreign_keys.map { |fk| owner.attribute_before_last_save(fk) }

        if foreign_key_was.any? && model_was && model_was < ActiveRecord::Base
          update_counters_via_scope(model_was, foreign_key_was, -1)
        end
      end

      def target_changed?
        foreign_keys.any? { |fk| owner.attribute_changed?(fk) } ||
          (!foreign_key_present? && target&.new_record?)
      end

      def target_previously_changed?
        foreign_keys.any? { |fk| owner.attribute_previously_changed?(fk) }
      end

      def saved_change_to_target?
        foreign_keys.any? { |fk| owner.saved_change_to_attribute?(fk) }
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
          return unless require_counter_update? && foreign_key_present?

          if target && !stale_target?
            target.increment!(reflection.counter_cache_column, by, touch: reflection.options[:touch])
          else
            fk_values = foreign_keys.map { |fk| owner._read_attribute(fk) }
            update_counters_via_scope(klass, fk_values, by)
          end
        end

        def update_counters_via_scope(klass, foreign_key_values, by)
          return if foreign_key_values.any?(&:nil?)

          scope = klass.unscoped.where!(Hash[primary_keys(klass).zip(foreign_key_values)])
          scope.update_counters(reflection.counter_cache_column => by, touch: reflection.options[:touch])
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def replace_keys(record, force: false)
          target_key_values = record ? primary_keys(record.class).map { |key| record._read_attribute(key) } : []

          if force || foreign_keys.map { |fk| owner._read_attribute(fk) } != target_key_values
            owner_pk = Array(owner.class.primary_key)
            foreign_keys.each_with_index do |key, index|
              next if record.nil? && owner_pk.include?(key)
              owner[key] = target_key_values[index]
            end
          end
        end

        def primary_keys(klass)
          Array(reflection.association_primary_key(klass))
        end

        def foreign_keys
          Array(reflection.foreign_key)
        end

        def foreign_key_present?
          foreign_keys.all? { |fk| owner._read_attribute(fk) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          attributes = foreign_keys.map do |fk|
            owner._read_attribute(fk) { |n| owner.send(:missing_attribute, n, caller) }
          end
          attributes if attributes.any?
        end
    end
  end
end
