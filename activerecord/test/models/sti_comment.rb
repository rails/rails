class StiComment < ActiveRecord::Base
  belongs_to :item, :polymorphic => true, :class_name => ->(type) { type.classify.constantize }
end
