class Keyboard < ActiveRecord::Base
  attribute :name, :string, default: -> { 'A nice keyboard' }
  self.primary_key = 'key_number'
end
