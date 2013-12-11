class MixedCaseMonkey < ApplicationRecord
  self.primary_key = 'monkeyID'

  belongs_to :man
end
