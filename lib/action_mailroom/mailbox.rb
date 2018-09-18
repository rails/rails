require "active_support/rescuable"

class ActionMailroom::Mailbox
  include ActiveSupport::Rescuable

  class << self
    def receive(inbound_email)
      new(inbound_email).process_with_state_and_exception_handling
    end

    def routing(routes)
      @router = ActionMailroom::Router.new(routes)
    end
  end

  attr_reader :inbound_email
  delegate :mail, to: :inbound_email

  def initialize(inbound_email)
    @inbound_email = inbound_email
  end

  def process_with_state_and_exception_handling
    inbound_email.processing!
    process
    inbound_email.delivered!
  rescue => exception
    inbound_email.failed!
    rescue_with_handler(exception) || raise
  end

  def process
    # Overwrite in subclasses
  end
end
