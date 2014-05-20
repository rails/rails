module ActiveJob
  class LogSubscriber < ActiveSupport::LogSubscriber
    def enqueue(event)
      payload = event.payload
      params  = payload[:params]
      adapter = payload[:adapter]
      job     = payload[:job]

      info "ActiveJob enqueued to #{adapter.name.demodulize} job #{job.name}: #{params.inspect}"
    end

    def enqueue_at(event)
      payload = event.payload
      params  = payload[:params]
      adapter = payload[:adapter]
      job     = payload[:job]
      time    = payload[:timestamp]

      info "ActiveJob enqueued at #{time} to #{adapter.name.demodulize} job #{job.name}: #{params.inspect}"
    end

    def perform_error(event)
      payload = event.payload
      params  = payload[:params]
      job     = payload[:job]
      error   = payload[:error]

      warn "ActiveJob caught error executing #{job} with #{params.inspect}: #{error.message}"
    end

    def logger
      ActiveJob::Base.logger
    end
  end
end

ActiveJob::LogSubscriber.attach_to :active_job
