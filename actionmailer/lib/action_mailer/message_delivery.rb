# frozen_string_literal: true

require "delegate"

module ActionMailer
  # The <tt>ActionMailer::MessageDelivery</tt> class is used by
  # ActionMailer::Base when creating a new mailer.
  # <tt>MessageDelivery</tt> is a wrapper (+Delegator+ subclass) around a lazy
  # created <tt>Mail::Message</tt>. You can get direct access to the
  # <tt>Mail::Message</tt>, deliver the email or schedule the email to be sent
  # through Active Job.
  #
  #   Notifier.welcome(User.first)               # an ActionMailer::MessageDelivery object
  #   Notifier.welcome(User.first).deliver_now   # sends the email
  #   Notifier.welcome(User.first).deliver_later # enqueue email delivery as a job through Active Job
  #   Notifier.welcome(User.first).message       # a Mail::Message object
  class MessageDelivery < Delegator
    def initialize(mailer_class, action, *args) # :nodoc:
      @mailer_class, @action, @args = mailer_class, action, args

      # The mail is only processed if we try to call any methods on it.
      # Typical usage will leave it unloaded and call deliver_later.
      @processed_mailer = nil
      @mail_message = nil
    end
    ruby2_keywords(:initialize)

    # Method calls are delegated to the Mail::Message that's ready to deliver.
    def __getobj__ # :nodoc:
      @mail_message ||= processed_mailer.message
    end

    # Unused except for delegator internals (dup, marshalling).
    def __setobj__(mail_message) # :nodoc:
      @mail_message = mail_message
    end

    # Returns the resulting Mail::Message
    def message
      __getobj__
    end

    # Was the delegate loaded, causing the mailer action to be processed?
    def processed?
      @processed_mailer || @mail_message
    end

    # Enqueues the email to be delivered through Active Job. When the
    # job runs it will send the email using +deliver_now!+. That means
    # that the message will be sent bypassing checking +perform_deliveries+
    # and +raise_delivery_errors+, so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_later!
    #   Notifier.welcome(User.first).deliver_later!(wait: 1.hour)
    #   Notifier.welcome(User.first).deliver_later!(wait_until: 10.hours.from_now)
    #   Notifier.welcome(User.first).deliver_later!(priority: 10)
    #
    # Options:
    #
    # * <tt>:wait</tt> - Enqueue the email to be delivered with a delay
    # * <tt>:wait_until</tt> - Enqueue the email to be delivered at (after) a specific date / time
    # * <tt>:queue</tt> - Enqueue the email on the specified queue
    # * <tt>:priority</tt> - Enqueues the email with the specified priority
    #
    # By default, the email will be enqueued using <tt>ActionMailer::MailDeliveryJob</tt>. Each
    # <tt>ActionMailer::Base</tt> class can specify the job to use by setting the class variable
    # +delivery_job+.
    #
    #   class AccountRegistrationMailer < ApplicationMailer
    #     self.delivery_job = RegistrationDeliveryJob
    #   end
    def deliver_later!(options = {})
      enqueue_delivery :deliver_now!, options
    end

    # Enqueues the email to be delivered through Active Job. When the
    # job runs it will send the email using +deliver_now+.
    #
    #   Notifier.welcome(User.first).deliver_later
    #   Notifier.welcome(User.first).deliver_later(wait: 1.hour)
    #   Notifier.welcome(User.first).deliver_later(wait_until: 10.hours.from_now)
    #   Notifier.welcome(User.first).deliver_later(priority: 10)
    #
    # Options:
    #
    # * <tt>:wait</tt> - Enqueue the email to be delivered with a delay.
    # * <tt>:wait_until</tt> - Enqueue the email to be delivered at (after) a specific date / time.
    # * <tt>:queue</tt> - Enqueue the email on the specified queue.
    # * <tt>:priority</tt> - Enqueues the email with the specified priority
    #
    # By default, the email will be enqueued using <tt>ActionMailer::MailDeliveryJob</tt>. Each
    # <tt>ActionMailer::Base</tt> class can specify the job to use by setting the class variable
    # +delivery_job+.
    #
    #   class AccountRegistrationMailer < ApplicationMailer
    #     self.delivery_job = RegistrationDeliveryJob
    #   end
    def deliver_later(options = {})
      enqueue_delivery :deliver_now, options
    end

    # Delivers an email without checking +perform_deliveries+ and +raise_delivery_errors+,
    # so use with caution.
    #
    #   Notifier.welcome(User.first).deliver_now!
    #
    def deliver_now!
      processed_mailer.handle_exceptions do
        message.deliver!
      end
    end

    # Delivers an email:
    #
    #   Notifier.welcome(User.first).deliver_now
    #
    def deliver_now
      processed_mailer.handle_exceptions do
        message.deliver
      end
    end

    private
      # Returns the processed Mailer instance. We keep this instance
      # on hand so we can delegate exception handling to it.
      def processed_mailer
        @processed_mailer ||= @mailer_class.new.tap do |mailer|
          mailer.process @action, *@args
        end
      end

      def enqueue_delivery(delivery_method, options = {})
        if processed?
          ::Kernel.raise "You've accessed the message before asking to " \
            "deliver it later, so you may have made local changes that would " \
            "be silently lost if we enqueued a job to deliver it. Why? Only " \
            "the mailer method *arguments* are passed with the delivery job! " \
            "Do not access the message in any way if you mean to deliver it " \
            "later. Workarounds: 1. don't touch the message before calling " \
            "#deliver_later, 2. only touch the message *within your mailer " \
            "method*, or 3. use a custom Active Job instead of #deliver_later."
        else
          @mailer_class.delivery_job.set(options).perform_later(
            @mailer_class.name, @action.to_s, delivery_method.to_s, args: @args)
        end
      end
  end
end
