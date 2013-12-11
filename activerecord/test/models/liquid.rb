class Liquid < ApplicationRecord
  self.table_name = :liquid
  has_many :molecules, -> { distinct }
end
