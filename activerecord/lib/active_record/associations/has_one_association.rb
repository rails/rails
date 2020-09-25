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

      def delete(method = options[:dependent])
        if load_target
          case method
          when :delete
            target.delete
          when :destroy
            target.destroyed_by_association = reflection
            target.destroy
            throw(:abort) unless target.destroyed?
          when :destroy_async
            primary_key_column = target.class.primary_key.to_sym
            id = target.send(primary_key_column)

            enqueue_destroy_association(
              owner_model_name: owner.class.to_s,
              owner_id: owner.id,
              association_class: reflection.klass.to_s,
              association_ids: [id],
              association_primary_key_column: primary_key_column,
              ensuring_owner_was_method: options.fetch(:ensuring_owner_was, nil)
            )
          when :nullify
            target.update_columns(nullified_owner_attributes) if target.persisted?
          end
        end
      end

      private
        def replace(record, save = true)
          raise_on_type_mismatch!(record) if record

          return target unless load_target || record

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
            if target.persisted?
              target.destroy
            end
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

        def _create_record(attributes, raise_error = false, &block)
          unless owner.persisted?
            raise ActiveRecord::RecordNotSaved, "You cannot call create unless the parent is saved"
          end

          super
        end
    end
  end
end
