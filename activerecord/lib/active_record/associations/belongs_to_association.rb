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
          if reflection.foreign_key.is_a?(Array)
            primary_key_column = reflection.active_record_primary_key
            id = reflection.foreign_key.map { |col| owner.public_send(col) }
          else
            primary_key_column = reflection.active_record_primary_key
            id = owner.public_send(reflection.foreign_key)
          end

          association_class = if reflection.polymorphic?
            owner.public_send(reflection.foreign_type)
          else
            reflection.klass
          end

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: association_class.to_s,
            association_ids: [id],
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

        foreign_key_was = owner.attribute_before_last_save(reflection.foreign_key)

        if foreign_key_was && model_was < ActiveRecord::Base
          update_counters_via_scope(model_was, foreign_key_was, -1)
        end
      end

      def target_changed?
        owner.attribute_changed?(reflection.foreign_key) || (!foreign_key_present? && target&.new_record?)
      end

      def target_previously_changed?
        owner.attribute_previously_changed?(reflection.foreign_key)
      end

      def saved_change_to_target?
        owner.saved_change_to_attribute?(reflection.foreign_key)
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
              update_counters_via_scope(klass, owner._read_attribute(reflection.foreign_key), by)
            end
          end
        end

        def update_counters_via_scope(klass, foreign_key, by)
          scope = klass.unscoped.where!(primary_key(klass) => foreign_key)
          scope.update_counters(reflection.counter_cache_column => by, touch: reflection.options[:touch])
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def replace_keys(record, force: false)
          reflection_fk = reflection.foreign_key
          if reflection_fk.is_a?(Array)
            target_key_values = record ? Array(primary_key(record.class)).map { |key| record._read_attribute(key) } : []

            if force || reflection_fk.map { |fk| owner._read_attribute(fk) } != target_key_values
              reflection_fk.each_with_index do |key, index|
                owner[key] = target_key_values[index]
              end
            end
          else
            target_key_value = record ? record._read_attribute(primary_key(record.class)) : nil

            if force || owner._read_attribute(reflection_fk) != target_key_value
              owner[reflection_fk] = target_key_value
            end
          end
        end

        def primary_key(klass)
          reflection.association_primary_key(klass)
        end

        def foreign_key_present?
          Array(reflection.foreign_key).all? { |fk| owner._read_attribute(fk) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          foreign_key = reflection.foreign_key
          if foreign_key.is_a?(Array)
            attributes = foreign_key.map do |fk|
              owner._read_attribute(fk) { |n| owner.send(:missing_attribute, n, caller) }
            end
            attributes if attributes.any?
          else
            owner._read_attribute(foreign_key) { |n| owner.send(:missing_attribute, n, caller) }
          end
        end
    end
  end
end
