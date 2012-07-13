class Liquid < ActiveRecord::Base
  self.table_name = :liquid
  has_many :molecules, -> { uniq }
end

