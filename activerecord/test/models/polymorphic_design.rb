class PolymorphicDesign < ActiveRecord::Base
  belongs_to :designable, :polymorphic => true
end