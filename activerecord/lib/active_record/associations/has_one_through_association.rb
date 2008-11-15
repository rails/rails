module ActiveRecord
  module Associations
    class HasOneThroughAssociation < HasManyThroughAssociation
      
      def create_through_record(new_value) #nodoc:
        klass = @reflection.through_reflection.klass

        current_object = @owner.send(@reflection.through_reflection.name)
        
        if current_object
          current_object.update_attributes(construct_join_attributes(new_value))
        else
          @owner.send(@reflection.through_reflection.name,  klass.send(:create, construct_join_attributes(new_value)))
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
