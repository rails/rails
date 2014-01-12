class Interest < ActiveRecord::Base
  belongs_to :man, :inverse_of => :interests
  belongs_to :polymorphic_man, :polymorphic => true, :inverse_of => :polymorphic_interests
  belongs_to :zine, :inverse_of => :interests
end
