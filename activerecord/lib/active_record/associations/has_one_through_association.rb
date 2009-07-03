require "active_record/associations/through_association_scope"

module ActiveRecord
  module Associations
    class HasOneThroughAssociation < HasOneAssociation
      include ThroughAssociationScope

      def replace(new_value)
        create_through_record(new_value)
        @target = new_value
      end

      private

      def create_through_record(new_value) #nodoc:
        klass = @reflection.through_reflection.klass

        current_object = @owner.send(@reflection.through_reflection.name)

        if current_object
          new_value ? current_object.update_attributes(construct_join_attributes(new_value)) : current_object.destroy
        else
          @owner.send(@reflection.through_reflection.name,  klass.send(:create, construct_join_attributes(new_value))) if new_value
        end
      end

    private
      def find_target
        with_scope(construct_scope) { @reflection.klass.find(:first) }
      end
    end
  end
end
