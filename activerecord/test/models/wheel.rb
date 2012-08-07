class Wheel < ActiveRecord::Base
  belongs_to :wheelable, :polymorphic => true, :counter_cache => true
  before_destroy :detachable?

  def detachable?
    wheelable.name != "De Lorean"
  end
end
