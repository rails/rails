class ShipPart < ActiveRecord::Base
  belongs_to :ship

  validates_presence_of :name
end