class WarehouseThing < ActiveRecord::Base
  set_table_name "warehouse-things"

  validates_uniqueness_of :value
end