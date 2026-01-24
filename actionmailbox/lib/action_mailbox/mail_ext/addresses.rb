# frozen_string_literal: true

module Mail
  class Message
    def from_address
      address_list(header[:from])&.addresses&.first
    end

    def reply_to_address
      address_list(header[:reply_to])&.addresses&.first
    end

    def recipients_addresses
      to_addresses + cc_addresses + bcc_addresses + x_original_to_addresses + x_forwarded_to_addresses
    end

    def to_addresses
      Array(address_list(header[:to])&.addresses)
    end

    def cc_addresses
      Array(address_list(header[:cc])&.addresses)
    end

    def bcc_addresses
      Array(address_list(header[:bcc])&.addresses)
    end

    def x_original_to_addresses
      Array(header[:x_original_to]).collect { |header| Mail::Address.new header.to_s }
    end

    def x_forwarded_to_addresses
      Array(header[:x_forwarded_to]).collect { |header| Mail::Address.new header.to_s }
    end

    private
      def address_list(obj)
        if obj.respond_to?(:element)
          # Mail 2.8+
          obj.element
        else
          # Mail <= 2.7.x
          obj&.address_list
        end
      end
  end
end
