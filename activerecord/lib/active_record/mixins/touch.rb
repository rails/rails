module ActiveRecord
  module Mixins
    # Including this mixins will record when objects of the class are created in a datetime column called "created_at"
    # and when its updated in another datetime column called "updated_at".
    #
    #   class Bill < ActiveRecord::Base
    #     include ActiveRecord::Mixins::Touch
    #   end
    #
    #   bill = Bill.create("amount" => 100)
    #   bill.created_at # => Time.now at the moment of Bill.create
    #   bill.updated_at # => Time.now at the moment of Bill.create
    #
    #   bill.update_attribute("amount", 150)
    #   bill.created_at # => Time.now at the moment of Bill.create
    #   bill.updated_at # => Time.now at the moment of bill.update_attribute
    module Touch
      def self.append_features(base)
        super
        base.class_eval do
          before_create :touch_on_create
          before_update :touch_on_update

          def touch_on_create
            self.created_at = self.updated_at = Time.now
          end

          def touch_on_update
            self.updated_at = Time.now
          end
        end
      end  
    end
  end
end