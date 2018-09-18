class ActionMailroom::Mailbox
  class << self
    def receive(inbound_email)
      new(inbound_email).process
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

  def process
  end
end
