class Tagging < ActiveRecord::Base
  belongs_to :tag
  belongs_to :super_tag, :class_name => 'Tag', :foreign_key => 'super_tag_id'
  belongs_to :taggable, :polymorphic => true, :counter_cache => true
end