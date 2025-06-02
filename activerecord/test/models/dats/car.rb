# frozen_string_literal: true

# DATS = Deprecated Associations Test Suite.
class DATS::Car < ActiveRecord::Base
  self.lock_optimistically = false

  has_many :tyres, class_name: "DATS::Tyre", dependent: :destroy
  has_many :deprecated_tyres, class_name: "DATS::Tyre", dependent: :destroy, deprecated: true

  accepts_nested_attributes_for :tyres, :deprecated_tyres

  has_one :bulb, class_name: "DATS::Bulb", dependent: :destroy
  has_one :deprecated_bulb, class_name: "DATS::Bulb", dependent: :destroy, deprecated: true

  accepts_nested_attributes_for :bulb, :deprecated_bulb
end
