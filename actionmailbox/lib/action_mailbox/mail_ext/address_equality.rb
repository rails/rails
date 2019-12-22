# frozen_string_literal: true

module Mail
  class Address
    def ==(other_address)
      other_address.is_a?(Mail::Address) && to_s == other_address.to_s
    end
  end
end
