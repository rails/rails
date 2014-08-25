module ActiveJob
  module QueueName
    extend ActiveSupport::Concern

    module ClassMethods
      mattr_accessor(:queue_name_prefix)
      mattr_accessor(:default_queue_name) { "default" }

      def queue_as(part_name=nil, &block)
        if block_given?
          self.queue_name = block
        else
          self.queue_name = queue_name_from_part(part_name)
        end
      end

      def queue_name_from_part(part_name) #:nodoc:
        queue_name = part_name.to_s.presence || default_queue_name
        name_parts = [queue_name_prefix.presence, queue_name]
        name_parts.compact.join('_')
      end
    end

    included do
      class_attribute :queue_name, instance_accessor: false
      self.queue_name = default_queue_name
    end

    # Returns the name of the queue the job will be run on
    def queue_name
      if @queue_name.is_a?(Proc)
        @queue_name = self.class.queue_name_from_part(instance_exec(&@queue_name))
      end
      @queue_name
    end

  end
end
