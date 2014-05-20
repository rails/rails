require 'active_support/core_ext/string/filters'

module ActiveJob
  class LogSubscriber < ActiveSupport::LogSubscriber
    def enqueue(event)
      info "Enqueued #{event.payload[:job].name} to #{queue_name(event)}" + args_info(event)
    end

    def enqueue_at(event)
      info "Enqueued #{event.payload[:job].name} to #{queue_name(event)} at #{event.payload[:timestamp]}" + args_info(event)
    end

    private
      def queue_name(event)
        event.payload[:adapter].name.demodulize.remove('Adapter')
      end
    
      def args_info(event)
        event.payload[:args].any? ? ": #{event.payload[:args].inspect}" : ""
      end
      
      def logger
        ActiveJob::Base.logger
      end
  end
end

ActiveJob::LogSubscriber.attach_to :active_job
