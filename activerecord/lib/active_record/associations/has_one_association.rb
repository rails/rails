module ActiveRecord
  # = Active Record Belongs To Has One Association
  module Associations
    class HasOneAssociation < AssociationProxy #:nodoc:
      def create(attributes = {})
        new_record(:create_association, attributes)
      end

      def create!(attributes = {})
        new_record(:create_association!, attributes)
      end

      def build(attributes = {})
        new_record(:build_association, attributes)
      end

      def replace(record, save = true)
        record = record.target if AssociationProxy === record
        raise_on_type_mismatch(record) unless record.nil?
        load_target

        if @target && @target != record
          remove_target!(@reflection.options[:dependent])
        end

        if record
          set_owner_attributes(record)
          set_inverse_instance(record)
        end

        @target = record
        loaded

        if @owner.persisted? && record && save
          unless record.save
            raise RecordNotSaved, "Failed to save the new associated #{@reflection.name}."
          end
        end
      end

      private
        def find_target
          scoped.first.tap { |record| set_inverse_instance(record) }
        end

        def association_scope
          super.order(@reflection.options[:order])
        end

        alias creation_attributes construct_owner_attributes

        def new_record(method, attributes)
          record = scoped.scoping { @reflection.send(method, attributes) }
          replace(record, false)
          record
        end

        def remove_target!(method)
          if [:delete, :destroy].include?(method)
            @target.send(method)
          else
            @target[@reflection.foreign_key] = nil

            if @target.persisted? && @owner.persisted?
              unless @target.save
                @target[@reflection.foreign_key] = @target.send("#{@reflection.foreign_key}_was")
                raise RecordNotSaved, "Failed to remove the existing associated #{@reflection.name}. " +
                                      "The record failed to save when after its foreign key was set to nil."
              end
            end
          end
        end
    end
  end
end
