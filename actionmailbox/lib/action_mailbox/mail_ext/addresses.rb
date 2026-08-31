# frozen_string_literal: true

module Mail
  class Message
    def from_address
      header[:from]&.element&.addresses&.first
    end

    def reply_to_address
      header[:reply_to]&.element&.addresses&.first
    end

    def recipients_addresses
      to_addresses + cc_addresses + bcc_addresses + x_original_to_addresses + x_forwarded_to_addresses
    end

    def to_addresses
      Array(header[:to]&.element&.addresses)
    end

    def cc_addresses
      Array(header[:cc]&.element&.addresses)
    end

    def bcc_addresses
      Array(header[:bcc]&.element&.addresses)
    end

    def x_original_to_addresses
      Array(header[:x_original_to]).collect { |header| Mail::Address.new header.to_s }
    end

    def x_forwarded_to_addresses
      Array(header[:x_forwarded_to]).collect { |header| Mail::Address.new header.to_s }
    end
  end
end
