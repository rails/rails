# frozen_string_literal: true

require "active_support/callbacks"

module ActiveJob
  # = Active Job Callbacks
  #
  # Active Job provides hooks during the life cycle of a job. Callbacks allow you
  # to trigger logic during this cycle. Available callbacks are:
  #
  # * <tt>before_enqueue</tt>
  # * <tt>around_enqueue</tt>
  # * <tt>after_enqueue</tt>
  # * <tt>before_perform</tt>
  # * <tt>around_perform</tt>
  # * <tt>after_perform</tt>
  #
  # NOTE: Calling the same callback multiple times will overwrite previous callback definitions.
  #
  module Callbacks
    extend  ActiveSupport::Concern
    include ActiveSupport::Callbacks

    class << self
      include ActiveSupport::Callbacks
      define_callbacks :execute
    end

    included do
      define_callbacks :perform
      define_callbacks :enqueue

      class_attribute :return_false_on_aborted_enqueue, instance_accessor: false, instance_predicate: false
      self.return_false_on_aborted_enqueue = false
    end

    # These methods will be included into any Active Job object, adding
    # callbacks for +perform+ and +enqueue+ methods.
    module ClassMethods
      # Defines a callback that will get called right before the
      # job's perform method is executed.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     before_perform do |job|
      #       UserMailer.notify_video_started_processing(job.arguments.first)
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def before_perform(*filters, &blk)
        set_callback(:perform, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # job's perform method has finished.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     after_perform do |job|
      #       UserMailer.notify_video_processed(job.arguments.first)
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def after_perform(*filters, &blk)
        set_callback(:perform, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the job's perform method.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     around_perform do |job, block|
      #       UserMailer.notify_video_started_processing(job.arguments.first)
      #       block.call
      #       UserMailer.notify_video_processed(job.arguments.first)
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def around_perform(*filters, &blk)
        set_callback(:perform, :around, *filters, &blk)
      end

      # Defines a callback that will get called right before the
      # job is enqueued.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     before_enqueue do |job|
      #       $statsd.increment "enqueue-video-job.try"
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def before_enqueue(*filters, &blk)
        set_callback(:enqueue, :before, *filters, &blk)
      end

      # Defines a callback that will get called right after the
      # job is enqueued.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     after_enqueue do |job|
      #       $statsd.increment "enqueue-video-job.success"
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def after_enqueue(*filters, &blk)
        set_callback(:enqueue, :after, *filters, &blk)
      end

      # Defines a callback that will get called around the enqueuing
      # of the job.
      #
      #   class VideoProcessJob < ActiveJob::Base
      #     queue_as :default
      #
      #     around_enqueue do |job, block|
      #       $statsd.time "video-job.process" do
      #         block.call
      #       end
      #     end
      #
      #     def perform(video_id)
      #       Video.find(video_id).process
      #     end
      #   end
      #
      def around_enqueue(*filters, &blk)
        set_callback(:enqueue, :around, *filters, &blk)
      end
    end
  end
end
