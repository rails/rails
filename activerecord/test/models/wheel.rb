class Wheel < ApplicationModel
  belongs_to :wheelable, :polymorphic => true, :counter_cache => true
end
