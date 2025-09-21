# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Car < ActiveRecord::Base
  self.lock_optimistically = false

  has_many :tires, class_name: "DATS::Tire", dependent: :destroy
  has_many :deprecated_tires, class_name: "DATS::Tire", dependent: :destroy, deprecated: true

  accepts_nested_attributes_for :tires, :deprecated_tires

  has_one :bulb, class_name: "DATS::Bulb", dependent: :destroy
  has_one :deprecated_bulb, class_name: "DATS::Bulb", dependent: :destroy, deprecated: true

  accepts_nested_attributes_for :bulb, :deprecated_bulb
end
