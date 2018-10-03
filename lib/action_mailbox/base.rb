require "active_support/rescuable"

require "action_mailbox/callbacks"
require "action_mailbox/routing"

class ActionMailbox::Base
  include ActiveSupport::Rescuable
  include ActionMailbox::Callbacks, ActionMailbox::Routing

  attr_reader :inbound_email
  delegate :mail, :bounced!, to: :inbound_email

  delegate :logger, to: ActionMailbox

  def self.receive(inbound_email)
    new(inbound_email).perform_processing
  end

  def initialize(inbound_email)
    @inbound_email = inbound_email
  end

  def perform_processing
    run_callbacks :process do
      track_status_of_inbound_email do
        process
      end
    end
  rescue => exception
    # TODO: Include a reference to the inbound_email in the exception raised so error handling becomes easier
    rescue_with_handler(exception) || raise
  end

  def process
    # Overwrite in subclasses
  end

  def bounce_with(message)
    inbound_email.bounced!
    message.deliver_later
  end

  private
    def track_status_of_inbound_email
      inbound_email.processing!
      yield
      inbound_email.delivered! unless inbound_email.bounced?
    rescue => exception
      inbound_email.failed!
      raise
    end
end
