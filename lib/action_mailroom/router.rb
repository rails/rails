class ActionMailroom::Router
  class RoutingError < StandardError; end

  def initialize
    @routes = []
  end

  def add_routes(routes)
    routes.each do |(address, mailbox_name)|
      add_route address, to: mailbox_name
    end
  end

  def add_route(address, to:)
    routes.append Route.new(address, to: to)
  end

  def route(inbound_email)
    if mailbox = locate_mailbox(inbound_email)
      mailbox.receive(inbound_email)
    else
      raise RoutingError
    end
  end

  private
    attr_reader :routes

    def locate_mailbox(inbound_email)
      routes.detect { |route| route.match?(inbound_email) }.try(:mailbox_class)
    end
end

require "action_mailroom/router/route"
