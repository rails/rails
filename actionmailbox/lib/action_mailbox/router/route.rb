# frozen_string_literal: true

module ActionMailbox
  # Encapsulates a route, which can then be matched against an inbound_email and provide a lookup of the matching
  # mailbox class. See examples for the different route addresses and how to use them in the ActionMailbox::Base
  # documentation.
  class Router::Route
    attr_reader :address, :mailbox_name

    def initialize(address, to:)
      @address, @mailbox_name = address, to

      ensure_valid_address
    end

    def match?(inbound_email)
      case address
      when :all
        true
      when String
        inbound_email.mail.recipients.any? { |recipient| address.casecmp?(recipient) }
      when Regexp
        inbound_email.mail.recipients.any? { |recipient| address.match?(recipient) }
      when Proc
        address.call(inbound_email)
      else
        address.match?(inbound_email)
      end
    end

    def mailbox_class
      "#{mailbox_name.to_s.camelize}Mailbox".constantize
    end

    private
      def ensure_valid_address
        unless [ Symbol, String, Regexp, Proc ].any? { |klass| address.is_a?(klass) } || address.respond_to?(:match?)
          raise ArgumentError, "Expected a Symbol, String, Regexp, Proc, or matchable, got #{address.inspect}"
        end
      end
  end
end
