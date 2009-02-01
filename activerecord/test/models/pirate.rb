class Pirate < ActiveRecord::Base
  belongs_to :parrot
  has_and_belongs_to_many :parrots
  has_many :treasures, :as => :looter

  has_many :treasure_estimates, :through => :treasures, :source => :price_estimates

  # These both have :autosave enabled because accepts_nested_attributes_for is used on them.
  has_one :ship
  has_many :birds

  accepts_nested_attributes_for :parrots, :birds, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }
  accepts_nested_attributes_for :ship, :allow_destroy => true

  validates_presence_of :catchphrase
end
