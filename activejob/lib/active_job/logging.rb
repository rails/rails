# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"

module ActiveJob
  module Logging
    extend ActiveSupport::Concern

    included do
      ##
      # Accepts a logger conforming to the interface of Log4r or the default
      # Ruby +Logger+ class. You can retrieve this logger by calling +logger+ on
      # either an Active Job job class or an Active Job job instance.
      cattr_accessor :logger, default: ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))

      ##
      # Configures whether a job's arguments should be logged. This can be
      # useful when a job's arguments may be sensitive and so should not be
      # logged.
      #
      # The value defaults to +true+, but this can be configured with
      # +config.active_job.log_arguments+. Additionally, individual jobs can
      # also configure a value, which will apply to themselves and any
      # subclasses.
      class_attribute :log_arguments, instance_accessor: false, default: true

      around_enqueue(prepend: true) { |_, block| tag_logger(&block) }
    end

    def perform_now # :nodoc:
      tag_logger(self.class.name, self.job_id) { super }
    end

    private
      def tag_logger(*tags, &block)
        if logger.respond_to?(:tagged)
          tags.unshift "ActiveJob" unless logger_tagged_by_active_job?
          logger.tagged(*tags, &block)
        else
          yield
        end
      end

      def logger_tagged_by_active_job?
        logger.formatter.current_tags.include?("ActiveJob")
      end
  end
end
