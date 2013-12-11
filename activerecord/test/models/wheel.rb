class Wheel < ApplicationRecord
  belongs_to :wheelable, :polymorphic => true, :counter_cache => true
end
