module ActiveJob
  module QueueName
    extend ActiveSupport::Concern

    # Includes the ability to override the default queue name and prefix.
    module ClassMethods
      mattr_accessor(:queue_name_prefix)
      mattr_accessor(:default_queue_name) { "default" }

      # Specifies the name of the queue to process the job on.
      #
      #   class PublishToFeedJob < ActiveJob::Base
      #     queue_as :feeds
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      def queue_as(part_name=nil, &block)
        self.queue_name = if block_given?
          block
        else
          queue_name_from_part(part_name)
        end
      end

      def queue_name_from_part(part_name) #:nodoc:
        queue_name = part_name || default_queue_name
        name_parts = [queue_name_prefix.presence, queue_name]
        name_parts.compact.join(queue_name_delimiter)
      end
    end

    included do
      class_attribute :queue_name, instance_accessor: false
      class_attribute :queue_name_delimiter, instance_accessor: false

      self.queue_name = default_queue_name
      self.queue_name_delimiter = '_' # set default delimiter to '_'
    end

    # Returns the name of the queue the job will be run on
    def queue_name
      if @queue_name.respond_to? :call
        @queue_name = self.class.queue_name_from_part(instance_exec(&@queue_name))
      end
      @queue_name
    end

  end
end
