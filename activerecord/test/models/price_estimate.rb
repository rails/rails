class PriceEstimate < ApplicationRecord
  belongs_to :estimate_of, :polymorphic => true
  belongs_to :thing, polymorphic: true
end
