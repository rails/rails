module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < SingularAssociation #:nodoc:
      def replace(record, save = true)
        record = check_record(record)
        load_target

        @reflection.klass.transaction do
          if @target && @target != record
            remove_target!(@reflection.options[:dependent])
          end

          if record
            set_inverse_instance(record)
            set_owner_attributes(record)

            if @owner.persisted? && save && !record.save
              nullify_owner_attributes(record)
              set_owner_attributes(@target)
              raise RecordNotSaved, "Failed to save the new associated #{@reflection.name}."
            end
          end
        end

        self.target = record
      end

      protected

        def association_scope
          super.order(@reflection.options[:order])
        end

      private

        alias creation_attributes construct_owner_attributes

        # The reason that the save param for replace is false, if for create (not just build),
        # is because the setting of the foreign keys is actually handled by the scoping when
        # the record is instantiated, and so they are set straight away and do not need to be
        # updated within replace.
        def set_new_record(record)
          replace(record, false)
        end

        def remove_target!(method)
          if [:delete, :destroy].include?(method)
            @target.send(method)
          else
            nullify_owner_attributes(@target)

            if @target.persisted? && @owner.persisted? && !@target.save
              set_owner_attributes(@target)
              raise RecordNotSaved, "Failed to remove the existing associated #{@reflection.name}. " +
                                    "The record failed to save when after its foreign key was set to nil."
            end
          end
        end

        def nullify_owner_attributes(record)
          record[@reflection.foreign_key] = nil
        end
    end
  end
end
