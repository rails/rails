class Pirate < ActiveRecord::Base
  belongs_to :parrot
  has_and_belongs_to_many :parrots
  has_many :treasures, :as => :looter

  has_many :treasure_estimates, :through => :treasures, :source => :price_estimates

  validates_presence_of :catchphrase
end
