class WholesaleProduct < ActiveRecord::Base

  after_initialize :set_prices

  def set_prices
    if msrp.nil? && !wholesale.nil?
      self.msrp = 2 * wholesale
    elsif !msrp.nil? && wholesale.nil?
      self.wholesale = msrp / 2
    end
  end

end