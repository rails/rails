# frozen_string_literal: true

module ActiveSupport
  module InCents
    def in_cents
      return self if integer?

      (self * 100).to_i
    end
  end
end

Numeric.prepend ActiveSupport::InCents
