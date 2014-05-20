module ActiveJob
  module QueueAdapters
    class InlineAdapter
      class << self
        def queue(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end

        def queue_at(job, ts, *args)
          Thread.new do
            begin
              interval = Time.now.to_f - ts
              sleep(interval) if interval > 0
              job.new.perform *Parameters.deserialize(args)
            rescue => ex
              ActiveJob::Base.logger.info "Error performing #{job}: #{ex.message}"
            end
          end
        end
      end
    end
  end
end
