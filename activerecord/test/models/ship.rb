class Ship < ActiveRecord::Base
  self.record_timestamps = false

  belongs_to :pirate
  has_many :parts, :class_name => 'ShipPart', :autosave => true

  accepts_nested_attributes_for :pirate, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }

  validates_presence_of :name
end
