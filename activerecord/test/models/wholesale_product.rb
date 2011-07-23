class WholesaleProduct < ActiveRecord::Base

  after_initialize :set_prices

  def set_prices
    self.msrp = 2 * wholesale if wholesale
  end

end
