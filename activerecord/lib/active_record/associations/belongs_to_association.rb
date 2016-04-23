module ActiveRecord
  # = Active Record Belongs To Association
  module Associations
    class BelongsToAssociation < SingularAssociation #:nodoc:

      def handle_dependency
        target.send(options[:dependent]) if load_target
      end

      def replace(record)
        if record
          raise_on_type_mismatch!(record)
          update_counters_on_replace(record)
          replace_keys(record)
          set_inverse_instance(record)
          @updated = true
        else
          decrement_counters
          remove_keys
        end

        self.target = record
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      def decrement_counters # :nodoc:
        update_counters(-1)
      end

      def increment_counters # :nodoc:
        update_counters(1)
      end

      private

        def update_counters(by)
          if require_counter_update? && foreign_key_present?
            if target && !stale_target?
              target.increment!(reflection.counter_cache_column, by)
            else
              klass.update_counters(target_id, reflection.counter_cache_column => by)
            end
          end
        end

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def require_counter_update?
          reflection.counter_cache_column && owner.persisted?
        end

        def update_counters_on_replace(record)
          if require_counter_update? && different_target?(record)
            owner.instance_variable_set :@_after_replace_counter_called, true
            record.increment!(reflection.counter_cache_column)
            decrement_counters
          end
        end

        # Checks whether record is different to the current target, without loading it
        def different_target?(record)
          record.id != owner._read_attribute(reflection.foreign_key)
        end

        def replace_keys(record)
          owner[reflection.foreign_key] = record._read_attribute(reflection.association_primary_key(record.class))
        end

        def remove_keys
          owner[reflection.foreign_key] = nil
        end

        def foreign_key_present?
          owner._read_attribute(reflection.foreign_key)
        end

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && inverse.has_one?
        end

        def target_id
          if options[:primary_key]
            owner.send(reflection.name).try(:id)
          else
            owner._read_attribute(reflection.foreign_key)
          end
        end

        def stale_state
          result = owner._read_attribute(reflection.foreign_key) { |n| owner.send(:missing_attribute, n, caller) }
          result && result.to_s
        end
    end
  end
end
