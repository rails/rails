# test that attr_readonly isn't called on the :taggable polymorphic association
module Taggable
end

class Tagging < ActiveRecord::Base
  belongs_to :tag, :include => :tagging
  belongs_to :super_tag,   :class_name => 'Tag', :foreign_key => 'super_tag_id'
  belongs_to :invalid_tag, :class_name => 'Tag', :foreign_key => 'tag_id'
  belongs_to :taggable, :polymorphic => true, :counter_cache => true
end