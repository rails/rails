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
          update_counters(record)
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
        with_cache_name { |name| decrement_counter name }
      end

      def increment_counters # :nodoc:
        with_cache_name { |name| increment_counter name }
      end

      private

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def with_cache_name
          counter_cache_name = reflection.counter_cache_column
          return unless counter_cache_name && owner.persisted?
          yield counter_cache_name
        end

        def update_counters(record)
          with_cache_name do |name|
            return unless different_target? record
            record.class.increment_counter(name, record.id)
            decrement_counter name
          end
        end

        def decrement_counter(counter_cache_name)
          if foreign_key_present?
            klass.decrement_counter(counter_cache_name, target_id)
          end
        end

        def increment_counter(counter_cache_name)
          if foreign_key_present?
            klass.increment_counter(counter_cache_name, target_id)
            if target && !stale_target? && counter_cache_available_in_memory?(counter_cache_name)
              target.increment(counter_cache_name)
            end
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
          result = owner._read_attribute(reflection.foreign_key)
          result && result.to_s
        end

        def counter_cache_available_in_memory?(counter_cache_name)
          target.respond_to?(counter_cache_name)
        end
    end
  end
end
