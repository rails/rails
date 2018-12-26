# frozen_string_literal: true

class Mail::Address
  def ==(other_address)
    other_address.is_a?(Mail::Address) && to_s == other_address.to_s
  end
end
