class Liquid < ApplicationModel
  self.table_name = :liquid
  has_many :molecules, -> { distinct }
end
