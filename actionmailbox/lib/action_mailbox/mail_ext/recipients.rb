# frozen_string_literal: true

module Mail
  class Message
    def recipients
      Array(to) + Array(cc) + Array(bcc) + Array(header[:x_original_to]).map(&:to_s) +
        Array(header[:x_forwarded_to]).map(&:to_s)
    end
  end
end
