# frozen_string_literal: true

module Mail
  class Address
    def self.wrap(address)
      ActionMailbox.deprecator.warn(<<~MSG.squish)
        Mail::Address.wrap is deprecated and will be removed in Rails 8.2.
      MSG
      address.is_a?(Mail::Address) ? address : Mail::Address.new(address)
    end
  end
end
