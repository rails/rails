# frozen_string_literal: true

require "active_support/tagged_logging"
require "active_support/logger"

module ActiveJob
  module Logging # :nodoc:
    extend ActiveSupport::Concern

    included do
      cattr_accessor :logger, default: ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT))
      class_attribute :log_arguments, instance_accessor: false, default: true

      around_enqueue(prepend: true) { |_, block| tag_logger(&block) }
    end

    def perform_now
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
