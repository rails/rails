module ActionMailer::Async
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def method_missing(method_name, *args)
      if action_methods.include?(method_name.to_s)
        QueuedMessage.new(self, method_name, *args)
      else
        super
      end
    end
  end

  class QueuedMessage
    delegate :to_s, :to => :actual_message

    def initialize(mailer_class, method_name, *args)
      @mailer_class = mailer_class
      @method_name  = method_name
      *@args        = *args
    end

    def run
      actual_message.deliver
    end

    # Will push the message onto the Queue to be processed
    # To force message delivery dispite async pass `true`
    #    Emailer.welcome.deliver(true)
    def deliver(force = false)
      if force
        run
      else
        Rails.queue << self
      end
    end

    # The original ActionMailer message
    def actual_message
      @actual_message ||= @mailer_class.send(:new, @method_name, *@args).message
    end

    def method_missing(method_name, *args)
      actual_message.send(method_name, *args)
    end
  end
end
