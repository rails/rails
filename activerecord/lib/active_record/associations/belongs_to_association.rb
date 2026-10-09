# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module Associations
    # Active Record Belongs To Association
    # ====================================
    class BelongsToAssociation < SingularAssociation # :nodoc:
      attr_reader :foreign_key, :foreign_type

      def initialize(owner, reflection)
        super
        @foreign_key = reflection.foreign_key_definition.resolve_aliases(owner)
        @foreign_type = nil
        if reflection.polymorphic?
          @foreign_type = owner.resolve_alias(reflection.foreign_type)
        end
      end

      def association_route(record = nil)
        reflection.association_route(origin_class: owner.class, destination_class: record ? record.class : klass)
      end

      def handle_dependency
        return unless load_target

        case options[:dependent]
        when :destroy
          raise ActiveRecord::Rollback unless target.destroy
        when :destroy_async
          primary_key_column = reflection.active_record_primary_key
          ids = foreign_key.map { |col| owner.public_send(col) }

          association_class = if reflection.polymorphic?
            owner.public_send(foreign_type)
          else
            reflection.klass
          end

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: association_class.to_s,
            association_ids: foreign_key.composite? ? [ids] : ids,
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

        foreign_key_was = foreign_key.map_value { |key| owner.attribute_before_last_save(key) }
        foreign_key_was = nil if foreign_key.composite? && !foreign_key_was.all?

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
          primary_key = primary_key(klass)
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
          if record
            target_key = primary_key(record.class)
            return if !force && keys_match?(record, target_key)

            foreign_key.zip(target_key) do |column, target_column|
              owner.write_attribute(column, record.read_attr(target_column))
            end
          else
            owner_pk = owner.class.primary_key_definition

            # Preserve shared primary key columns only if another foreign key
            # column can be cleared to disassociate the record.
            preserve_owner_pk = !foreign_key.subset?(owner_pk)

            foreign_key.each do |key|
              next if preserve_owner_pk && owner_pk.include?(key)
              owner.write_attribute(key, nil)
            end
          end
        end

        def keys_match?(record, target_key)
          fk = foreign_key
          return false unless fk.composite? == target_key.composite?

          if target_key.composite?
            return false unless fk.length == target_key.length

            fk.zip(target_key) do |column, target_column|
              return false unless owner.read_attr(column) == record.read_attr(target_column)
            end
            true
          else
            owner.read_attr(fk.name) == record.read_attr(target_key.name)
          end
        end

        def primary_key(klass)
          reflection.association_primary_key_definition(klass)
        end

        def foreign_key_present?
          foreign_key.all? { |fk| owner.read_attr(fk) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          value = foreign_key.map_value do |fk|
            owner.read_attr(fk)
          end
          foreign_key.composite? ? (value if value.any?) : value
        end
    end
  end
end
