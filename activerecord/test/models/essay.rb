class Essay < ApplicationModel
  belongs_to :writer, :primary_key => :name, :polymorphic => true
  belongs_to :category, :primary_key => :name
  has_one :owner, :primary_key => :name
end
