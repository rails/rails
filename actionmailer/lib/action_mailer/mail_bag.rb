require 'active_support/concern'

module ActionMailer
  # = Action Mailer Mail Bag Helper
  module MailBagHelper
    extend ActiveSupport::Concern

    # <tt>MailBag</tt> is acting as a wrapper for <tt>Mail::Message</tt>,
    # allowing you to do various things with the mailer such as chaining the
    # headers and perform a bulk mailing without having to create multiple
    # emails yourself.
    #
    # The API of this <tt>MailBag</tt> is the same as Action Mailer API. You
    # can call your mailer method on it as you normally do in Action Mailer.
    # Any method call will override your configuration in your mailer method.
    #
    # == Available Methods
    #
    # These methods can be called before or after you call your normal mailer
    # method, and are available to be called from the your <tt>Mailer</tt> class:
    #
    # * <tt>subject</tt> - Specifies a subject on an E-Mail.
    # * <tt>to</tt> - Specifies a list of recipients. Note that if you pass a list
    #   of E-Mail addresses, it will send a single E-Mail with multiple recipients.
    # * <tt>to_bulk</tt> - Specifies a list of recipients. However, separate E-Mail
    #   will be created for each of the recipient.
    # * <tt>from</tt> - Specifies sender's E-Mail address.
    # * <tt>cc</tt> - Specifies CC recipients.
    # * <tt>bcc</tt> - Specifies BCC recipients.
    # * <tt>reply_to</tt> - Specifies a reply to E-Mail address.
    # * <tt>date</tt> - Specifies a timestamp of the E-Mail.
    # * <tt>headers</tt> - Specifies the custom headers of the E-Mail.
    #
    # These methods are available only after you've called your mailer method:
    #
    # * <tt>mails</tt> - Retrieve a list of finished <tt>Mail::Message</tt> objects.
    # * <tt>merge!</tt> - Merge a list of headers into this <tt>MailBag</tt> object.
    # * <tt>deliver</tt> - Delivers emails by calling <tt>#deliver</tt> on each of the
    #   <tt>Mail::Message</tt> object.
    #
    # == Examples
    #
    # Sending an E-Mail to user:
    #
    #    Notification.welcome.to(@user.email).deliver
    #
    # Sending bulk E-Mail to multiple users:
    #
    #    Notification.package_expire.to_bulk(@users.map(&:emails)).deliver
    module ClassMethods
      [:subject, :to, :to_bulk, :from, :cc, :bcc, :reply_to, :date, :headers].each do |method|
        class_eval <<-ACCESSORS, __FILE__, __LINE__ + 1
          def #{method}(#{method})
            MailBag.new(self).#{method}(#{method})
          end
        ACCESSORS
      end
    end
  end

  # A wrapper class for <tt>ActionMailer::Base</tt> which allow methods to be
  # chainable and bulk-mailingable. You can see the list of methods you can call
  # and usage example of this by consulting <tt>ActionMailer::MailBagHelper::ClassMethods</tt>
  # documentation.
  class MailBag
    class UnspecifiedMailerMethod < ArgumentError; end

    # Store the class instance of the mailer
    attr_reader :mailer

    # The list of headers, used for generate getter/setter methods
    HEADERS = [:subject, :cc, :bcc, :reply_to, :date]

    delegate :each, :to => :mails

    # Create a <tt>MailBag</tt> object which will handle the chaining and
    # bulk mailing
    def initialize(mailer, headers = {})
      @message_template = nil
      @mailer = mailer
      @headers = headers
    end

    # Create the getter/setter methods
    HEADERS.each do |method|
      class_eval <<-ACCESSORS, __FILE__, __LINE__ + 1
        def #{method}(#{method} = nil)
          if #{method}
            @mails = nil
            @headers[:#{method}] = #{method}
            self
          else
            @headers[:#{method}] || @message_template.#{method}
          end
        end
      ACCESSORS
    end

    # Get and set the sender E-Mail address. If this method is called with an
    # argument, it will set the E-Mail address and returns the <tt>MailBag</tt>
    # object. If no argument, it will returns the array of sender E-Mail address.
    #
    # Note: This method returns an array to be compatible with <tt>Mail::Message</tt>.
    def from(emails = nil)
      if emails
        @mails = nil
        @headers[:from] = Array.wrap(emails)
        self
      else
        @headers[:from] || @message_template.from
      end
    end


    # Get and set the recipient E-Mail address. If this method is called with an
    # argument, it will set the E-Mail address in a single E-Mail and returns the
    # <tt>MailBag</tt> object. If no argument, it will returns the array of sender
    # E-Mail address.
    #
    # Note: This method returns an array to be compatible with <tt>Mail::Message</tt>.
    # This method may also returning an nested array of recipients if the bulk mailing
    # recipients was specified by using <tt>#to_bulk</tt> method:
    #
    #    mail = Notification.welcome.to("konata@luckystar.net")
    #    mail.to    # => ["konata@luckystar.net"]
    #
    #    mail = Notification.welcome.to(["konata@luckystar.net", "kagami@luckystar.net"])
    #    mail.to    # => ["konata@luckystar.net", "kagami@luckystar.net"]
    #
    #    mail = Notification.welcome.to_bulk(["konata@luckystar.net", "kagami@luckystar.net"])
    #    mail.to    # => [["konata@luckystar.net"], ["kagami@luckystar.net"]]
    def to(emails = nil)
      if emails
        @mails = nil

        # Store this as a nested array instead of normal array because this
        # array is shared with the <tt>#to_bulk</tt> to. The outer array represents
        # the number of messages, and the inner array represents the number of recipients
        # of that message.
        @headers[:to] = [ Array.wrap(emails) ]
        self
      else
        # This condition is needed to not return a nested array if there's only
        # going to be a single E-Mail generated.
        if @headers[:to].present?
          if @headers[:to].length == 1
            @headers[:to].first
          else
            @headers[:to]
          end
        else
          @message_template.to
        end
      end
    end

    # Sets the E-Mail addresses to perform bulk mailing. The difference between
    # using this method and <tt>#to</tt> method is that this method will create
    # multiple <tt>Mail::Message</tt> objects when you're trying to deliver the
    # E-Mail, resulting multiple E-Mails to multiple recipients, not single
    # E-Mail to multiple recipents.
    def to_bulk(recipients)
      @mails = nil
      @headers[:to] = recipients.map{ |recipient| Array.wrap(recipient) }
      self
    end

    # Get and set the custom headers of the E-Mail. If this method is called with
    # an argument, it will merge your argument hash to your <tt>Mail::Message</tt>
    # header and return <tt>self</tt>. If no argument, it will returns the hash
    # of headers.
    def headers(headers = nil)
      if headers
        merge!(headers)
      else
        @headers.merge(@message_template.try(:headers) || {})
      end
    end

    # Merge your custom headers into this <tt>MailBag</tt> instance.
    def merge!(headers = {})
      @mails = nil
      @headers.merge!(headers)
      self
    end

    # Returns a list of <tt>Mail::Message</tt> objects which represent the real
    # E-Mail which will be sent. This method will always return an array.
    #
    # Calling this method before calling your mailer's method will raise an
    # UnspecifiedMailerMethod error.
    def mails
      raise UnspecifiedMailerMethod, "You have to call mailer's method first before getting mails collection or delivers it." if @message_template.nil?

      @mails ||= if @headers[:to].present?
                   # Clone mail message to preserve the original message
                   @headers[:to].map do |recipient|
                     @message_template.clone.tap do |message|
                       message.headers(@headers.merge(:to => recipient))
                     end
                   end
                 else
                   [@message_template.clone.tap{ |message| message.headers(@headers) }]
                 end
    end

    # Calls the <tt>#deliver</tt> method on each of the <tt>Mail::Message</tt>
    # object to perform the delivery of E-Mail.
    def deliver
      mails.each(&:deliver)
    end

    protected

      # Handles the call to the mailer's method, which isn't defined in this
      # <tt>MailBag</tt> class.
      def method_missing(name, *args)
        if @message_template
          @message_template.send(name, *args)
        elsif @mailer.respond_to?(name)
          # It's a bad hack, but this is the only way to prevent circular call
          @message_template = @mailer.send(:new, name, *args).message
          self
        else
          super
        end
      end
  end
end
