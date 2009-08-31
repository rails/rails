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
        elsif new_value
          if @owner.new_record?
            self.target = new_value
            through_association = @owner.send(:association_instance_get, @reflection.through_reflection.name)
            through_association.build(construct_join_attributes(new_value))
          else
            @owner.send(@reflection.through_reflection.name, klass.create(construct_join_attributes(new_value)))
          end
        end
      end

    private
      def find_target
        with_scope(construct_scope) { @reflection.klass.find(:first) }
      end
    end
  end
end
