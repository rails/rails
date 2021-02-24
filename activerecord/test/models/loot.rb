# frozen_string_literal: true

class Loot < ActiveRecord::Base
  has_many :loot_parrots, class_name: "LootParrot"
  has_many :parrots, through: :loot_parrots
end
