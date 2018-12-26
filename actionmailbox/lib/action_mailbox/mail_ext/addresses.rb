# frozen_string_literal: true

module Mail
  class Message
    def from_address
      header[:from]&.address_list&.addresses&.first
    end

    def recipients_addresses
      to_addresses + cc_addresses + bcc_addresses + x_original_to_addresses
    end

    def to_addresses
      Array(header[:to]&.address_list&.addresses)
    end

    def cc_addresses
      Array(header[:cc]&.address_list&.addresses)
    end

    def bcc_addresses
      Array(header[:bcc]&.address_list&.addresses)
    end

    def x_original_to_addresses
      Array(header[:x_original_to]).collect { |header| Mail::Address.new header.to_s }
    end
  end
end
