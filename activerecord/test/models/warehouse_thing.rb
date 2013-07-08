class WarehouseThing < ActiveRecord::Base
  self.table_name = "warehouse-things"

  validates :value, uniqueness: true
end
