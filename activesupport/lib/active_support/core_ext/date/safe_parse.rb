# frozen_string_literal: true

require "date"

class Date #:nodoc:
  # Safely parse a string without the need of rescuing possible exceptions
  def self.safe_parse(string, fallback = nil)
    parse(string)
  rescue TypeError, ArgumentError
    fallback
  end
end
