class LegacyThing < ApplicationModel
  self.locking_column = :version
end
