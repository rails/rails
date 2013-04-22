module ActiveRecord
  # = Active Record Belongs To Association
  module Associations
    class BelongsToAssociation < SingularAssociation #:nodoc:

      def handle_dependency
        target.send(options[:dependent]) if load_target
      end

      def replace(record)
        raise_on_type_mismatch!(record) if record

        update_counters(record)
        replace_keys(record)
        set_inverse_instance(record)

        @updated = true if record

        self.target = record
      end

      def reset
        super
        @updated = false
      end

      def updated?
        @updated
      end

      private

        def find_target?
          !loaded? && foreign_key_present? && klass
        end

        def update_counters(record)
          counter_cache_name = reflection.counter_cache_column

          if counter_cache_name && owner.persisted? && different_target?(record)
            if record
              record.class.increment_counter(counter_cache_name, record.id)
            end

            if foreign_key_present?
              klass.decrement_counter(counter_cache_name, target_id)
            end
          end
        end

        # Checks whether record is different to the current target, without loading it
        def different_target?(record)
          if record.nil? 
            owner[reflection.foreign_key] 
          else
            record.id != owner[reflection.foreign_key]
          end
        end

        def replace_keys(record)
          if record
            owner[reflection.foreign_key] = record[reflection.association_primary_key(record.class)]
          else
            owner[reflection.foreign_key] = nil
          end
        end

        def foreign_key_present?
          owner[reflection.foreign_key]
        end

        # NOTE - for now, we're only supporting inverse setting from belongs_to back onto
        # has_one associations.
        def invertible_for?(record)
          inverse = inverse_reflection_for(record)
          inverse && inverse.macro == :has_one
        end

        def target_id
          if options[:primary_key]
            owner.send(reflection.name).try(:id)
          else
            owner[reflection.foreign_key]
          end
        end

        def stale_state
          owner[reflection.foreign_key] && owner[reflection.foreign_key].to_s
        end
    end
  end
end
