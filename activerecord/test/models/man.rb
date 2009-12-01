class Man < ActiveRecord::Base
  has_one :face, :inverse_of => :man
  has_many :interests, :inverse_of => :man
  # These are "broken" inverse_of associations for the purposes of testing
  has_one :dirty_face, :class_name => 'Face', :inverse_of => :dirty_man
  has_many :secret_interests, :class_name => 'Interest', :inverse_of => :secret_man
end
