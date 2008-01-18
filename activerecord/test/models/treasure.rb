class Treasure < ActiveRecord::Base
  has_and_belongs_to_many :parrots
  belongs_to :looter, :polymorphic => true
end
