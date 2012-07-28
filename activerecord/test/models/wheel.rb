class Wheel < ActiveRecord::Base
  belongs_to :wheelable, :polymorphic => true, :counter_cache => true
  attr_accessor :brand_new
  before_destroy :detachable?

  def detachable?
    wheelable.name != "De Lorean"
  end
end
