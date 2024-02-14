class Note < ActiveRecord::Base
  belongs_to :envelope, inverse_of: :note, autosave: true
end