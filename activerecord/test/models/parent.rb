class Parent < ActiveRecord::Base
  has_one :child, inverse_of: :parent, autosave: true
  belongs_to :grandparent, inverse_of: :parent, autosave: true

  @@after_save_foo = 0
  @@after_validation_foo = 0

  after_save  -> { @@after_save_foo += 1 }
  after_validation -> { @@after_validation_foo += 1 }
end