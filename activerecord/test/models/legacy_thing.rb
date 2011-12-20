class LegacyThing < ActiveRecord::Base
  self.locking_column = :version
end
