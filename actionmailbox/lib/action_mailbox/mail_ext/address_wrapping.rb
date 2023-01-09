# frozen_string_literal: true

module Mail # :nodoc: all
  class Address
    def self.wrap(address)
      address.is_a?(Mail::Address) ? address : Mail::Address.new(address)
    end
  end
end
