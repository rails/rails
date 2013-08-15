class MixedCaseMonkey < ActiveRecord::Base
  self.primary_key = 'monkeyID'

  belongs_to :man
end
