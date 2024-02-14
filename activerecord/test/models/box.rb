class Box < ActiveRecord::Base
  has_one :envelope, inverse_of: :box, autosave: true
end