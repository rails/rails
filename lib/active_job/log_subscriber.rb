require 'active_support/core_ext/string/filters'

module ActiveJob
  class LogSubscriber < ActiveSupport::LogSubscriber
    def enqueue(event)
      queue_name = event.payload[:adapter].name.demodulize.remove('Adapter')
      job_name   = event.payload[:job].name
      args       = event.payload[:args].any? ? ": #{event.payload[:args].inspect}" : ""

      info "Enqueued #{job_name} to #{queue_name}" + args
    end

    def enqueue_at(event)
      queue_name = event.payload[:adapter].name.demodulize.remove('Adapter')
      job_name   = event.payload[:job].name
      args       = event.payload[:args].any? ? ": #{event.payload[:args].inspect}" : ""
      time       = event.payload[:timestamp]

      info "Enqueued #{job_name} to #{queue_name} at #{time}" + args
    end

    def logger
      ActiveJob::Base.logger
    end
  end
end

ActiveJob::LogSubscriber.attach_to :active_job
