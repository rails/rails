class Interest < ActiveRecord::Base
  belongs_to :man, :inverse_of => :interests, :automatic_inverse_of => false
  belongs_to :polymorphic_man, :polymorphic => true, :inverse_of => :polymorphic_interests
  belongs_to :zine, :inverse_of => :interests
end
