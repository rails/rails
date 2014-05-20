require 'active_support/core_ext/string/filters'

module ActiveJob
  module Logging
    mattr_accessor(:logger) { ActiveSupport::Logger.new(STDOUT) }

    class LogSubscriber < ActiveSupport::LogSubscriber
      def enqueue(event)
        info "Enqueued #{event.payload[:job].name} to #{queue_name(event)}" + args_info(event)
      end

      def enqueue_at(event)
        info "Enqueued #{event.payload[:job].name} to #{queue_name(event)} at #{enqueued_at(event)}" + args_info(event)
      end
      
      def perform(event)
        info "Performed #{event.payload[:job].name} to #{queue_name(event)}" + args_info(event)
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
