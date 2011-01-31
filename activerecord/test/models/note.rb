class Note < ActiveRecord::Base
  default_scope where(:deleted => 0)
  scope :english, where(:language => 'en')
end
