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
    # Overwrite in subclasses
  end
  
  private
    def track_status_of_inbound_email
      inbound_email.processing!
      yield
      inbound_email.delivered!
    rescue => exception
      inbound_email.failed!
      raise
    end
end
