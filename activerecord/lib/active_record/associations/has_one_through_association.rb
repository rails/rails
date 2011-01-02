module ActiveRecord
  # = Active Record Has One Through Association
  module Associations
    class HasOneThroughAssociation < HasOneAssociation
      include ThroughAssociation

      def replace(new_value)
        create_through_record(new_value)
        @target = new_value
        loaded
      end

      private

      def create_through_record(new_value)
        proxy  = @owner.send(@reflection.through_reflection.name) ||
                 @owner.send(:association_instance_get, @reflection.through_reflection.name)
        record = proxy.target

        if record && !new_value
          record.destroy
        elsif new_value
          attributes = construct_join_attributes(new_value)

          if record
            record.update_attributes(attributes)
          elsif @owner.new_record?
            proxy.build(attributes)
          else
            proxy.create(attributes)
          end
        end
      end

      def find_target
        scoped.first
      end
    end
  end
end
