# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module Associations
    # Active Record Belongs To Association
    # ====================================
    class BelongsToAssociation < SingularAssociation # :nodoc:
      attr_reader :foreign_key, :foreign_type

      # The foreign key and type are physical names for the owner's class, for
      # use with the non-resolving attribute APIs and dirty tracking.
      def initialize(owner, reflection)
        super
        @foreign_key = reflection.association_route(origin_class: owner.class)._reference_origin_key
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
          route = association_route(target)
          destination_key = route.destination_key
          id = destroy_association_async_id(route)
          if !destination_key.composite? && id.is_a?(Array)
            # The job queries a list of ids, so use tuple syntax to keep this
            # Array-valued id together as one value.
            destination_key = ActiveRecord::Key.for(destination_key.columns)
            id = [id]
          end
          association_class = if reflection.polymorphic?
            owner.public_send(foreign_type)
          else
            klass
          end

          enqueue_destroy_association(
            owner_model_name: owner.class.to_s,
            owner_id: owner.id,
            association_class: association_class.to_s,
            association_ids: [id],
            association_primary_key_column: destroy_association_async_columns(destination_key),
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
          route = reflection.association_route(origin_class: owner.class, destination_class: model_was)
          origin_key_was = route._origin_key.map_value { |key| owner.attribute_before_last_save(key) }
          update_counters_via_scope(model_was, origin_key_was, -1, route)
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
        # Prefer the target's persisted values, falling back to the owner for
        # values unavailable after a partial select.
        def destroy_association_async_id(route)
          origin_columns = route._origin_key.columns
          reference_destination_key = route._reference_destination_key
          route._destination_key.map_value.with_index do |destination_column, index|
            origin_value = owner._read_attribute!(origin_columns[index])
            if target._has_attribute?(destination_column)
              destination_value = target.attribute_in_database(destination_column)
              # An unselected primary key can be present as nil. Use the owner's
              # reference for that case, but preserve nil query-constraint values.
              if !destination_value.nil? || !reference_destination_key.include?(destination_column)
                destination_value
              else
                origin_value
              end
            else
              origin_value
            end
          end
        end

        def destroy_association_async_columns(key)
          declared_aliases = klass.attribute_aliases
          target_aliases = target.class.attribute_aliases
          key.map_value do |column|
            # The job queries the declared class, whose aliases may differ from
            # the assigned target's. In that case, pass the target's physical column.
            physical = target_aliases[column] || column
            (declared_aliases[column] || column) == physical ? column : physical
          end
        end

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
              route = association_route
              update_counters_via_scope(klass, route._origin_key._value_of(owner), by, route)
            end
          end
        end

        def update_counters_via_scope(klass, values, by, route)
          scope = klass.all_queries_scope.where!(route.destination_key.where_hash(values))
          scope.update_counters(reflection.counter_cache_column => by, touch: reflection.options[:touch])
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def replace_keys(record, force: false)
          if record.nil? && foreign_key_partially_overlaps_primary_key?
            clear_reference_with_shared_primary_key(force: force)
          else
            route = reflection.association_route(origin_class: owner.class, destination_class: record&.class)
            route.write(owner, record, force: force)
          end
        end

        def foreign_key_partially_overlaps_primary_key?
          primary_key = owner.class.primary_key_definition
          shared_count = foreign_key.count { |key| primary_key.include?(key) }
          shared_count > 0 && shared_count < foreign_key.size
        end

        def clear_reference_with_shared_primary_key(force:)
          reflection.association_route(origin_class: owner.class)
            .clear_reference(owner, preserve: owner.class.primary_key_definition, force: force)
        end

        def foreign_key_present?
          foreign_key.all? { |fk| owner._read_attribute(fk) }
        end

        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && (inverse.has_one? || inverse.klass.has_many_inversing)
        end

        def stale_state
          value = foreign_key.map_value do |fk|
            owner._read_attribute!(fk)
          end
          foreign_key.composite? ? (value if value.any?) : value
        end
    end
  end
end
