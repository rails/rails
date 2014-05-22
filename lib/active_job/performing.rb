require 'active_job/parameters'

module ActiveJob
  module Performing
    def perform_with_deserialization(*serialized_args)
      instrument_performing serialized_args
      perform *Parameters.deserialize(serialized_args)
    end

    def perform(*)
      raise NotImplementedError
    end
    
    private
      def instrument_performing(args)
        ActiveSupport::Notifications.instrument "perform.active_job", adapter: self.class.queue_adapter, job: self.class, args: args
      end
  end
end
