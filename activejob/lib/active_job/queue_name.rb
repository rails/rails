# frozen_string_literal: true

module ActiveJob
  module QueueName
    extend ActiveSupport::Concern

    # Includes the ability to override the default queue name and prefix.
    module ClassMethods
      mattr_accessor :default_queue_name, default: "default"

      # Specifies the name of the queue to process the job on.
      #
      #   class PublishToFeedJob < ActiveJob::Base
      #     queue_as :feeds
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      #
      # Can be given a block that will evaluate in the context of the job
      # allowing +self.arguments+ to be accessed so that a dynamic queue name
      # can be applied:
      #
      #   class PublishToFeedJob < ApplicationJob
      #     queue_as do
      #       post = self.arguments.first
      #
      #       if post.paid?
      #         :paid_feeds
      #       else
      #         :feeds
      #       end
      #     end
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      def queue_as(part_name = nil, &block)
        if block_given?
          self.queue_name = block
        else
          self.queue_name = queue_name_from_part(part_name)
        end
      end

      def queue_name_from_part(part_name) # :nodoc:
        queue_name = part_name || default_queue_name
        name_parts = [queue_name_prefix.presence, queue_name]
        -name_parts.compact.join(queue_name_delimiter)
      end
    end

    included do
      class_attribute :queue_name, instance_accessor: false, default: -> { self.class.default_queue_name }
      class_attribute :queue_name_delimiter, instance_accessor: false, default: "_"
      class_attribute :queue_name_prefix
    end

    # Returns the name of the queue the job will be run on.
    def queue_name
      if @queue_name.is_a?(Proc)
        @queue_name = self.class.queue_name_from_part(instance_exec(&@queue_name))
      end
      @queue_name
    end
  end
end
