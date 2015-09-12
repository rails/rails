require 'shoryuken'

module ActiveJob
  module QueueAdapters
    # == Shoryuken adapter for Active Job
    #
    # Shoryuken ("sho-ryu-ken") is a super-efficient AWS SQS thread based message processor.
    #
    # Read more about Shoryuken {here}[https://github.com/phstc/shoryuken].
    #
    # To use Shoryuken set the queue_adapter config to +:shoryuken+.
    #
    #   Rails.application.config.active_job.queue_adapter = :shoryuken
    class ShoryukenAdapter
      class << self
        def enqueue(job) #:nodoc:
          register_worker!(job)

          queue = Shoryuken::Client.queues(job.queue_name)
          queue.send_message(message(job))
        end

        def enqueue_at(job, timestamp) #:nodoc:
          register_worker!(job)

          delay = (timestamp - Time.current.to_f).round
          raise 'The maximum allowed delay is 15 minutes' if delay > 15.minutes

          queue = Shoryuken::Client.queues(job.queue_name)
          queue.send_message(message(job, delay_seconds: delay))
        end

        private

        def message(job, options = {})
          body = job.serialize

          { message_body: body,
            message_attributes: message_attributes }.merge(options)
        end

        def register_worker!(job)
          Shoryuken.register_worker(job.queue_name, JobWrapper)
        end

        def message_attributes
          @message_attributes ||= {
            'shoryuken_class' => {
              string_value: JobWrapper.to_s,
              data_type: 'String'
            }
          }
        end
      end

      class JobWrapper #:nodoc:
        include Shoryuken::Worker

        shoryuken_options body_parser: :json, auto_delete: true

        def perform(sqs_msg, hash)
          Base.execute hash
        end
      end
    end
  end
end
