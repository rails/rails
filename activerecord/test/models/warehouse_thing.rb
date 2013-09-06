class WarehouseThing < ApplicationModel
  self.table_name = "warehouse-things"

  validates_uniqueness_of :value
end
