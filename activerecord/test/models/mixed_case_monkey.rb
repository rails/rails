class MixedCaseMonkey < ApplicationModel
  self.primary_key = 'monkeyID'

  belongs_to :man
end
