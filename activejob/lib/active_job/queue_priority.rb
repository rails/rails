# frozen_string_literal: true

module ActiveJob
  module QueuePriority
    extend ActiveSupport::Concern

    # Includes the ability to override the default queue priority.
    module ClassMethods
      mattr_accessor :default_priority

      # Specifies the priority of the queue to create the job with.
      #
      #   class PublishToFeedJob < ActiveJob::Base
      #     queue_with_priority 50
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      #
      # Can be given a block that will evaluate in the context of the job
      # so that a dynamic priority can be applied:
      #
      #   class PublishToFeedJob < ApplicationJob
      #     queue_with_priority do
      #       post = self.arguments.first
      #
      #       if post.paid?
      #         10
      #       else
      #         50
      #       end
      #     end
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      def queue_with_priority(priority = nil, &block)
        if block_given?
          self.priority = block
        else
          self.priority = priority
        end
      end
    end

    included do
      class_attribute :priority, instance_accessor: false, default: default_priority
    end

    # Returns the priority that the job will be created with
    def priority
      if @priority.is_a?(Proc)
        @priority = instance_exec(&@priority)
      end
      @priority
    end
  end
end
