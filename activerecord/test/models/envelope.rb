class Envelope < ActiveRecord::Base
  has_one :note, inverse_of: :envelope, autosave: true
  belongs_to :box, inverse_of: :envelope, autosave: true

  @@after_save_foo = 0
  @@after_validation_foo = 0

  after_save  -> { @@after_save_foo += 1 }
  after_validation -> { @@after_validation_foo += 1 }
end