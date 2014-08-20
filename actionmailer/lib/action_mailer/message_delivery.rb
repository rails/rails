require 'delegate'

module ActionMailer

  # The ActionMailer::MessageDeliver class is used by ActionMailer::Base when
  # creating a new mailer. MessageDeliver is a wrapper (Delegator subclass)
  # around a lazy created Mail::Message. You can get direct access to the
  # Mail::Message, deliver the email or schedule the email to be sent through ActiveJob.
  #
  #   Notifier.welcome('david')               # an ActionMailer::MessageDeliver object
  #   Notifier.welcome('david').deliver_now   # sends the email
  #   Notifier.welcome('david').deliver_later # enqueue the deliver email job to ActiveJob
  #   Notifier.welcome('david').message       # a Mail::Message object
  class MessageDelivery < Delegator
    def initialize(mailer, mail_method, *args) #:nodoc:
      @mailer = mailer
      @mail_method = mail_method
      @args = args
    end

    def __getobj__ #:nodoc:
      @obj ||= @mailer.send(:new, @mail_method, *@args).message
    end

    def __setobj__(obj) #:nodoc:
      @obj = obj
    end

    # Returns the Mail::Message object
    def message
      __getobj__
    end

    # Enqueues the message to be delivered through ActiveJob. When the
    # ActiveJob job runs it will send the email using #deliver_now!. That
    # means that the message will be sent bypassing checking perform_deliveries
    # and raise_delivery_errors, so use with caution.
    #
    # ==== Examples
    #
    #   Notifier.welcome('david').deliver_later
    #   Notifier.welcome('david').deliver_later(in: 1.hour)
    #   Notifier.welcome('david').deliver_later(at: 10.hours.from_now)
    #
    # ==== Options
    # * <tt>in</tt>  - Enqueue the message to be delivered with a delay
    # * <tt>at</tt>  - Enqueue the message to be delivered at (after) a specific date / time
    def deliver_later!(options={})
      enqueue_delivery :deliver_now!, options
    end

    # Enqueues the message to be delivered through ActiveJob. When the
    # ActiveJob job runs it will send the email using #deliver_now.
    #
    # ==== Examples
    #
    #   Notifier.welcome('david').deliver_later
    #   Notifier.welcome('david').deliver_later(in: 1.hour)
    #   Notifier.welcome('david').deliver_later(at: 10.hours.from_now)
    #
    # ==== Options
    # * <tt>in</tt>  - Enqueue the message to be delivered with a delay
    # * <tt>at</tt>  - Enqueue the message to be delivered at (after) a specific date / time
    def deliver_later(options={})
      enqueue_delivery :deliver_now, options
    end

    # Delivers a message. The message will be sent bypassing checking perform_deliveries
    # and raise_delivery_errors, so use with caution.
    #
    #   Notifier.welcome('david').deliver_now!
    #
    def deliver_now!
      message.deliver!
    end

    # Delivers a message:
    #
    #   Notifier.welcome('david').deliver_now
    #
    def deliver_now
      message.deliver
    end

    def deliver! #:nodoc:
      ActiveSupport::Deprecation.warn "#deliver! is deprecated and will be removed in Rails 5. " \
        "Use #deliver_now! to deliver immediately or #deliver_later! to deliver through ActiveJob."
      deliver_now!
    end

    def deliver #:nodoc:
      ActiveSupport::Deprecation.warn "#deliver is deprecated and will be removed in Rails 5. " \
        "Use #deliver_now to deliver immediately or #deliver_later to deliver through ActiveJob."
      deliver_now
    end

    private

      def enqueue_delivery(delivery_method, options={})
        args = @mailer.name, @mail_method.to_s, delivery_method.to_s, *@args
        enqueue_method = :enqueue
        if options[:at]
          enqueue_method = :enqueue_at
          args.unshift options[:at]
        elsif options[:in]
          enqueue_method = :enqueue_in
          args.unshift options[:in]
        end
        ActionMailer::DeliveryJob.send enqueue_method, *args
      end
  end
end
