# frozen_string_literal: true

class LootParrot < ActiveRecord::Base
  belongs_to :parrot
  belongs_to :loot
end
