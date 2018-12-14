# frozen_string_literal: true

class Mail::Message
  def recipients
    Array(to) + Array(cc) + Array(bcc) + Array(header[:x_original_to]).map(&:to_s)
  end
end
