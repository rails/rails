module ActiveRecord
  # = Active Record Belongs To Associations
  module Associations
    class BelongsToAssociation < SingularAssociation #:nodoc:

      def handle_dependency
        target.send(options[:dependent]) if load_target
      end

      def replace(record)
        raise_on_type_mismatch(record) if record

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

        def stale_state
          owner[reflection.foreign_key] && owner[reflection.foreign_key].to_s
        end
    end
  end
end
