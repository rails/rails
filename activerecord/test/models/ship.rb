class Ship < ActiveRecord::Base
  self.record_timestamps = false

  belongs_to :pirate
  belongs_to :update_only_pirate, :class_name => 'Pirate'
  has_many :parts, :class_name => 'ShipPart', :autosave => true

  accepts_nested_attributes_for :pirate, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }
  accepts_nested_attributes_for :update_only_pirate, :update_only => true

  validates_presence_of :name
end
