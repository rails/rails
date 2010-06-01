class Tie < ActiveRecord::Base
  has_one :polymorphic_design, :as => :designable
  has_one :polymorphic_price, :as => :sellable
end