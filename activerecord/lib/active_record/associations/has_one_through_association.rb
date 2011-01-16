module ActiveRecord
  # = Active Record Has One Through Association
  module Associations
    class HasOneThroughAssociation < HasOneAssociation
      include ThroughAssociation

      def replace(record)
        create_through_record(record)
        self.target = record
      end

      private

      def create_through_record(new_value)
        proxy  = @owner.send(:association_proxy, @reflection.through_reflection.name)
        record = proxy.send(:load_target)

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
    end
  end
end
