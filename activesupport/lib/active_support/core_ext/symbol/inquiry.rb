# frozen_string_literal: true

require "active_support/core_ext/string/inquiry"

class Symbol
  # See String#inquiry.
  delegate :inquiry, to: :name
end
