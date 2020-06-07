# frozen_string_literal: true

module ActionMailbox
  # Encapsulates the routes that live on the ApplicationMailbox and performs the actual routing when
  # an inbound_email is received.
  class Router
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
      if mailbox = mailbox_for(inbound_email)
        mailbox.receive(inbound_email)
      else
        inbound_email.bounced!

        raise RoutingError
      end
    end

    def mailbox_for(inbound_email)
      routes.detect { |route| route.match?(inbound_email) }&.mailbox_class
    end

    private
      attr_reader :routes
  end
end

require "action_mailbox/router/route"
