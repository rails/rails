require 'active_support/core_ext/object/inclusion'

module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < SingularAssociation #:nodoc:
      def replace(record, save = true)
        raise_on_type_mismatch(record) if record
        load_target

        # If target and record are nil, or target is equal to record,
        # we don't need to have transaction.
        if (target || record) && target != record
          reflection.klass.transaction do
            remove_target!(options[:dependent]) if target && !target.destroyed?
  
            if record
              set_owner_attributes(record)
              set_inverse_instance(record)
  
              if owner.persisted? && save && !record.save
                nullify_owner_attributes(record)
                set_owner_attributes(target) if target
                raise RecordNotSaved, "Failed to save the new associated #{reflection.name}."
              end
            end
          end
        end

        self.target = record
      end

      def delete(method = options[:dependent])
        if load_target
          case method
            when :delete
              target.delete
            when :destroy
              target.destroy
            when :nullify
              target.update_attribute(reflection.foreign_key, nil)
          end
        end
      end

      private

        # The reason that the save param for replace is false, if for create (not just build),
        # is because the setting of the foreign keys is actually handled by the scoping when
        # the record is instantiated, and so they are set straight away and do not need to be
        # updated within replace.
        def set_new_record(record)
          replace(record, false)
        end

        def remove_target!(method)
          if method.in?([:delete, :destroy])
            target.send(method)
          else
            nullify_owner_attributes(target)

            if target.persisted? && owner.persisted? && !target.save
              set_owner_attributes(target)
              raise RecordNotSaved, "Failed to remove the existing associated #{reflection.name}. " +
                                    "The record failed to save when after its foreign key was set to nil."
            end
          end
        end

        def nullify_owner_attributes(record)
          record[reflection.foreign_key] = nil
        end
    end
  end
end
