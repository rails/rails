module ActiveJob
  module QueueName
    extend ActiveSupport::Concern

    module ClassMethods
      mattr_accessor(:default_queue_name) { "default" }

      def queue_as(part_name)
        self.queue_name = part_name.to_s.presence || default_queue_name
      end
    end

    included do
      class_attribute :queue_name
      self.queue_name = default_queue_name
    end
  end
end
