class LegacyThing < ApplicationRecord
  self.locking_column = :version
end
