# frozen_string_literal: true

class ShipPart < ActiveRecord::Base
  belongs_to :ship
  has_many :trinkets, class_name: 'Treasure', as: :looter
  accepts_nested_attributes_for :trinkets, allow_destroy: true
  accepts_nested_attributes_for :ship

  validates_presence_of :name
end
