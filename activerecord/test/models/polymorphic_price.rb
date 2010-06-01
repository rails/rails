class PolymorphicPrice < ActiveRecord::Base
  belongs_to :sellable, :polymorphic => true
end