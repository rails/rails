class PriceEstimate < ActiveRecord::Base
  belongs_to :estimate_of, :polymorphic => true
end
