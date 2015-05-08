module ActiveJob
  module MaxRetry
    extend ActiveSupport::Concern

    module ClassMethods

      mattr_accessor(:default_max_retry) { nil }

      def max_retry_from_part(max_retries) #:nodoc:
        ( "#{max_retries}".to_i > 0 ? "#{max_retries}".to_i : default_max_retry )
      end

    end

    included do
      # Specifies the max retry for the job.
      #
      #   class PublishToFeedJob < ActiveJob::Base
      #     max_retry 2
      #
      #     def perform(post)
      #       post.to_feed!
      #     end
      #   end
      def self.max_retry(max_retries=nil, &block)
        if block_given?
          @max_retry = block
        else
          if max_retries.nil?
            @max_retry
          else
            @max_retry = max_retry_from_part(max_retries)
          end
        end
      end

      def self.max_retry=(max_retries = nil)
        @max_retry = max_retry_from_part(max_retries)
      end
    end

    # Returns the max retry of current job
    def max_retry
      if @max_retry.is_a?(Proc)
        @max_retry = self.class.max_retry_from_part(instance_exec(&@max_retry))
      end
      @max_retry
    end

  end
end

