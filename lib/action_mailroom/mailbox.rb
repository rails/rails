require "active_support/rescuable"

require "action_mailroom/mailbox/callbacks"
require "action_mailroom/mailbox/routing"

class ActionMailroom::Mailbox
  include ActiveSupport::Rescuable
  include Callbacks, Routing

  attr_reader :inbound_email
  delegate :mail, to: :inbound_email

  def self.receive(inbound_email)
    new(inbound_email).perform_processing
  end


  def initialize(inbound_email)
    @inbound_email = inbound_email
  end

  def perform_processing
    inbound_email.processing!

    run_callbacks :process do
      process
    end

    inbound_email.delivered!
  rescue => exception
    inbound_email.failed!
    
    # TODO: Include a reference to the inbound_email in the exception raised so error handling becomes easier
    rescue_with_handler(exception) || raise
  end

  def process
    # Overwrite in subclasses
  end
end
