require 'active_support/core_ext/string/filters'

module ActiveJob
  module Logging
    extend ActiveSupport::Concern
    
    included do
      cattr_accessor(:logger) { ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) }

      before_enqueue do |job|
        if job.enqueued_at
          ActiveSupport::Notifications.instrument "enqueue_at.active_job", 
            adapter: job.class.queue_adapter, job: job.class, args: job.arguments, timestamp: job.enqueued_at
        else
          ActiveSupport::Notifications.instrument "enqueue.active_job",
            adapter: job.class.queue_adapter, job: job.class, args: job.arguments
        end
      end
      
      before_perform do |job|
        ActiveSupport::Notifications.instrument "perform.active_job",
          adapter: job.class.queue_adapter, job: job.class, args: job.arguments
      end
    end
    
    class LogSubscriber < ActiveSupport::LogSubscriber
      def enqueue(event)
        info "Enqueued #{event.payload[:job].name} to #{queue_name(event)}" + args_info(event)
      end

      def enqueue_at(event)
        info "Enqueued #{event.payload[:job].name} to #{queue_name(event)} at #{enqueued_at(event)}" + args_info(event)
      end

      def perform(event)
        info "Performed #{event.payload[:job].name} from #{queue_name(event)}" + args_info(event)
      end


      private
        def queue_name(event)
          event.payload[:adapter].name.demodulize.remove('Adapter')
        end

        def args_info(event)
          event.payload[:args].any? ? ": #{event.payload[:args].inspect}" : ""
        end

        def enqueued_at(event)
          Time.at(event.payload[:timestamp]).utc
        end

        def logger
          ActiveJob::Base.logger
        end
    end
  end
end

ActiveJob::Logging::LogSubscriber.attach_to :active_job
