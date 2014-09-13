class Device < ActiveRecord::Base

  def self.find_by_mac_address(address)
    super(address.downcase)
  end

end