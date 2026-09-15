# frozen_string_literal: true

module ActiveJob
  module QueueName
    extend ActiveSupport::Concern

    @default_queue_name = "default"
    singleton_class.attr_reader :default_queue_name # :nodoc:

    def self.default_queue_name=(name) # :nodoc:
      @default_queue_name = -name.to_s
    end

    # Includes the ability to override the default queue name and prefix.
    module ClassMethods
      delegate :default_queue_name, :default_queue_name=, to: QueueName

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
      # so that a dynamic queue name can be applied:
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
          self.queue_name = ActiveSupport::Ractors.try_shareable_proc(block)
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
      class_attribute :queue_name, instance_accessor: false, default: ActiveSupport::Ractors.shareable_proc { self.class.default_queue_name }
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
