# frozen_string_literal: true

module Mail
  def self.from_source(source)
    Mail.new Mail::Utilities.binary_unsafe_to_crlf(source.to_s)
  end
end
