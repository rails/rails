class ActionMailroom::Router
  def initialize(routes)
    @routes = routes
  end

  def route(inbound_email)
    locate_mailbox(inbound_email).receive(inbound_email)
  end

  private
    attr_reader :routes

    def locate_mailbox(inbound_email)
      "#{routes[inbound_email.mail.to.first].to_s.capitalize}Mailbox".constantize
    end
end
