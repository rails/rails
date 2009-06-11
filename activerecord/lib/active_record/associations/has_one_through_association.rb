module ActiveRecord
  module Associations
    class HasOneThroughAssociation < HasManyThroughAssociation

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
      def find(*args)
        super(args.merge(:limit => 1))
      end

      def find_target
        super.first
      end

      def reset_target!
        @target = nil
      end
    end
  end
end
