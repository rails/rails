# frozen_string_literal: true

require "active_support/rescuable"

require "action_mailbox/callbacks"
require "action_mailbox/routing"

module ActionMailbox
  # The base class for all application mailboxes. Not intended to be inherited from directly. Inherit from
  # +ApplicationMailbox+ instead, as that's where the app-specific routing is configured. This routing
  # is specified in the following ways:
  #
  #   class ApplicationMailbox < ActionMailbox::Base
  #     # Any of the recipients of the mail (whether to, cc, bcc) are matched against the regexp.
  #     routing /^replies@/i => :replies
  #
  #     # Any of the recipients of the mail (whether to, cc, bcc) needs to be an exact match for the string.
  #     routing "help@example.com" => :help
  #
  #     # Any callable (proc, lambda, etc) object is passed the inbound_email record and is a match if true.
  #     routing ->(inbound_email) { inbound_email.mail.to.size > 2 } => :multiple_recipients
  #
  #     # Any object responding to #match? is called with the inbound_email record as an argument. Match if true.
  #     routing CustomAddress.new => :custom
  #
  #     # Any inbound_email that has not been already matched will be sent to the BackstopMailbox.
  #     routing :all => :backstop
  #   end
  #
  # Application mailboxes need to override the #process method, which is invoked by the framework after
  # callbacks have been run. The callbacks available are: +before_processing+, +after_processing+, and
  # +around_processing+. The primary use case is ensure certain preconditions to processing are fulfilled
  # using +before_processing+ callbacks.
  #
  # If a precondition fails to be met, you can halt the processing using the +#bounced!+ method,
  # which will silently prevent any further processing, but not actually send out any bounce notice. You
  # can also pair this behavior with the invocation of an Action Mailer class responsible for sending out
  # an actual bounce email. This is done using the #bounce_with method, which takes the mail object returned
  # by an Action Mailer method, like so:
  #
  #   class ForwardsMailbox < ApplicationMailbox
  #     before_processing :ensure_sender_is_a_user
  #
  #     private
  #       def ensure_sender_is_a_user
  #         unless User.exist?(email_address: mail.from)
  #           bounce_with UserRequiredMailer.missing(inbound_email)
  #         end
  #       end
  #   end
  #
  # During the processing of the inbound email, the status will be tracked. Before processing begins,
  # the email will normally have the +pending+ status. Once processing begins, just before callbacks
  # and the #process method is called, the status is changed to +processing+. If processing is allowed to
  # complete, the status is changed to +delivered+. If a bounce is triggered, then +bounced+. If an unhandled
  # exception is bubbled up, then +failed+.
  #
  # Exceptions can be handled at the class level using the familiar
  # ActiveSupport::Rescuable approach:
  #
  #   class ForwardsMailbox < ApplicationMailbox
  #     rescue_from(ApplicationSpecificVerificationError) { bounced! }
  #   end
  class Base
    include ActiveSupport::Rescuable
    include ActionMailbox::Callbacks, ActionMailbox::Routing

    attr_reader :inbound_email
    delegate :mail, :delivered!, :bounced!, to: :inbound_email

    delegate :logger, to: ActionMailbox

    def self.receive(inbound_email)
      new(inbound_email).perform_processing
    end

    def initialize(inbound_email)
      @inbound_email = inbound_email
    end

    def perform_processing # :nodoc:
      track_status_of_inbound_email do
        run_callbacks :process do
          process
        end
      end
    rescue => exception
      # TODO: Include a reference to the inbound_email in the exception raised so error handling becomes easier
      rescue_with_handler(exception) || raise
    end

    def process
      # Override in subclasses
    end

    def finished_processing? # :nodoc:
      inbound_email.delivered? || inbound_email.bounced?
    end


    # Enqueues the given +message+ for delivery and changes the inbound email's status to +:bounced+.
    def bounce_with(message)
      inbound_email.bounced!
      message.deliver_later
    end

    private
      def track_status_of_inbound_email
        inbound_email.processing!
        yield
        inbound_email.delivered! unless inbound_email.bounced?
      rescue
        inbound_email.failed!
        raise
      end
  end
end

ActiveSupport.run_load_hooks :action_mailbox, ActionMailbox::Base
