# frozen_string_literal: true

class Ship < ActiveRecord::Base
  self.record_timestamps = false

  belongs_to :pirate
  belongs_to :update_only_pirate, class_name: 'Pirate'
  belongs_to :developer, dependent: :destroy
  has_many :parts, class_name: 'ShipPart'
  has_many :treasures

  accepts_nested_attributes_for :parts, allow_destroy: true
  accepts_nested_attributes_for :pirate, allow_destroy: true, reject_if: proc(&:empty?)
  accepts_nested_attributes_for :update_only_pirate, update_only: true

  validates_presence_of :name

  attr_accessor :cancel_save_from_callback
  before_save :cancel_save_callback_method, if: :cancel_save_from_callback
  def cancel_save_callback_method
    throw(:abort)
  end
end

class ShipWithoutNestedAttributes < ActiveRecord::Base
  self.table_name = 'ships'
  has_many :prisoners, inverse_of: :ship, foreign_key: :ship_id
  has_many :parts, class_name: 'ShipPart', foreign_key: :ship_id

  validates :name, presence: true, if: -> { true }
  validates :name, presence: true, if: -> { true }
end

class Prisoner < ActiveRecord::Base
  belongs_to :ship, autosave: true, class_name: 'ShipWithoutNestedAttributes', inverse_of: :prisoners
end

class FamousShip < ActiveRecord::Base
  self.table_name = 'ships'
  belongs_to :famous_pirate, foreign_key: :pirate_id
  validates_presence_of :name, on: :conference
end
