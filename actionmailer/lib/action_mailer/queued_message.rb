require 'delegate'

module ActionMailer
  class QueuedMessage < ::Delegator
    attr_reader :queue

    def initialize(queue, mailer_class, method_name, *args)
      @queue = queue
      @job   = DeliveryJob.new(mailer_class, method_name, args)
    end

    def __getobj__
      @job.message
    end

    # Queues the message for delivery.
    def deliver
      tap { @queue.push @job }
    end

    class DeliveryJob
      def initialize(mailer_class, method_name, args)
        @mailer_class = mailer_class
        @method_name  = method_name
        @args         = args
      end

      def message
        @message ||= @mailer_class.send(:new, @method_name, *@args).message
      end

      def run
        message.deliver
      end
    end
  end
end
