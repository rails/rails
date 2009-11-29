class Face < ActiveRecord::Base
  belongs_to :man, :inverse_of => :face
  belongs_to :polymorphic_man, :polymorphic => true, :inverse_of => :polymorphic_face
  # This is a "broken" inverse_of for the purposes of testing
  belongs_to :horrible_man, :class_name => 'Man', :inverse_of => :horrible_face
end
