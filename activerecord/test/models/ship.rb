class Ship < ActiveRecord::Base
  self.record_timestamps = false

  belongs_to :pirate
  belongs_to :update_only_pirate, :class_name => 'Pirate'
  has_many :parts, :class_name => 'ShipPart', :autosave => true

  accepts_nested_attributes_for :pirate, :allow_destroy => true, :reject_if => proc { |attributes| attributes.empty? }
  accepts_nested_attributes_for :update_only_pirate, :update_only => true

  validates_presence_of :name

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, :if => :cancel_save_from_callback
  def cancel_save_callback_method
    false
  end
end
