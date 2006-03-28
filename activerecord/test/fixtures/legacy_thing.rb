class LegacyThing < ActiveRecord::Base
  set_locking_column :version
end
