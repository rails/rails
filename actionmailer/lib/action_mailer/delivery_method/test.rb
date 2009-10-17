module ActionMailer
  module DeliveryMethod

    # A delivery method implementation designed for testing, which just appends each record to the :deliveries array
    class Test < Method
      def perform_delivery(mail)
        ActionMailer::Base.deliveries << mail
      end
    end

  end
end
