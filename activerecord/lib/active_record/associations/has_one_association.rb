# frozen_string_literal: true

module ActiveRecord
  module Associations
    # = Active Record Has One Association
    class HasOneAssociation < SingularAssociation #:nodoc:
      include ForeignAssociation

      def handle_dependency
        case options[:dependent]
        when :restrict_with_exception
          raise ActiveRecord::DeleteRestrictionError.new(reflection.name) if load_target

        when :restrict_with_error
          if load_target
            record = owner.class.human_attribute_name(reflection.name).downcase
            owner.errors.add(:base, :'restrict_dependent_destroy.has_one', record: record)
            throw(:abort)
          end

        else
          delete
        end
      end

      def replace(record, save = true)
        raise_on_type_mismatch!(record) if record
        load_target

        return target unless target || record

        assigning_another_record = target != record
        if assigning_another_record || record.has_changes_to_save?
          save &&= owner.persisted?

          transaction_if(save) do
            remove_target!(options[:dependent]) if target && !target.destroyed? && assigning_another_record

            if record
              set_owner_attributes(record)
              set_inverse_instance(record)

              if save && !record.save
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
            target.destroyed_by_association = reflection
            target.destroy unless target.destroyed?
          when :nullify
            target.update_columns(reflection.foreign_key => nil) if target.persisted?
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
          case method
          when :delete
            target.delete
          when :destroy
            target.destroyed_by_association = reflection
            target.destroy
          else
            nullify_owner_attributes(target)
            remove_inverse_instance(target)

            if target.persisted? && owner.persisted? && !target.save
              set_owner_attributes(target)
              raise RecordNotSaved, "Failed to remove the existing associated #{reflection.name}. " \
                                    "The record failed to save after its foreign key was set to nil."
            end
          end
        end

        def nullify_owner_attributes(record)
          record[reflection.foreign_key] = nil
        end

        def transaction_if(value)
          if value
            reflection.klass.transaction { yield }
          else
            yield
          end
        end
    end
  end
end
