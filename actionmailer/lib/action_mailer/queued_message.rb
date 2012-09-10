require 'delegate'

module ActionMailer
  class QueuedMessage < ::Delegator
    attr_reader :queue

    def initialize(queue, mailer_class, method_name, *args)
      @queue        = queue
      @mailer_class = mailer_class
      @method_name  = method_name
      @args         = args
    end

    def __getobj__
      @actual_message ||= @mailer_class.send(:new, @method_name, *@args).message
    end

    def run
      __getobj__.deliver
    end

    # Will push the message onto the Queue to be processed
    def deliver
      @queue << self
    end
  end
end
