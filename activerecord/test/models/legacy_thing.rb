class LegacyThing < ActiveRecord::Base
  self.locking_column = :version
  belongs_to :resource, polymorphic: true
end
