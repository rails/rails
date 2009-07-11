class Treasure < ActiveRecord::Base
  has_and_belongs_to_many :parrots
  belongs_to :looter, :polymorphic => true

  has_many :price_estimates, :as => :estimate_of

  accepts_nested_attributes_for :looter
end
