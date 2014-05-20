require 'sneakers'

module ActiveJob
  module QueueAdapters
    class SneakersAdapter
      class << self
        def queue(job, *args)
          JobWrapper.enqueue([job, *args])
        end
      end

      class JobWrapper
        include Sneakers::Worker

        self.from_queue("queue", {})

        def work(job, *args)
          job.new.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end
