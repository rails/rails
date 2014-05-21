module ActiveJob
  module QueueAdapters
    class InlineAdapter
      class << self
        def enqueue(job, *args)
          job.new.perform_with_deserialization *args
        end

        def enqueue_at(job, timestamp, *args)
          Thread.new do
            begin
              interval = Time.now.to_f - timestamp
              sleep(interval) if interval > 0
              job.new.perform_with_deserialization *args
            rescue => e
              ActiveJob::Base.logger.info "Error performing #{job}: #{e.message}"
            end
          end
        end
      end
    end
  end
end
