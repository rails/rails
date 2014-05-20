module ActiveJob
  class LogSubscriber < ActiveSupport::LogSubscriber
    def enqueue(event)
      payload = event.payload
      params  = payload[:params]
      adapter = payload[:adapter]
      job     = payload[:job]

      info "ActiveJob enqueued to #{adapter.name.demodulize} job #{job.name}: #{params.inspect}"
    end

    def logger
      ActiveJob::Base.logger
    end
  end
end

ActiveJob::LogSubscriber.attach_to :active_job
