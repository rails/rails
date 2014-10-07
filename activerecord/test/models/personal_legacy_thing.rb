class PersonalLegacyThing < ActiveRecord::Base
  self.locking_column = :version
  belongs_to :person, :counter_cache => true
end
