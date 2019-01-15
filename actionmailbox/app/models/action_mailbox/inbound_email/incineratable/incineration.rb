# frozen_string_literal: true

module ActionMailbox
  # Command class for carrying out the actual incineration of the +InboundMail+ that's been scheduled
  # for removal. Before the incineration – which really is just a call to +#destroy!+ – is run, we verify
  # that it's both eligible (by virtue of having already been processed) and time to do so (that is,
  # the +InboundEmail+ was processed after the +incinerate_after+ time).
  class InboundEmail::Incineratable::Incineration
    def initialize(inbound_email)
      @inbound_email = inbound_email
    end

    def run
      @inbound_email.destroy! if due? && processed?
    end

    private
      def due?
        @inbound_email.updated_at < ActionMailbox.incinerate_after.ago.end_of_day
      end

      def processed?
        @inbound_email.processed?
      end
  end
end
