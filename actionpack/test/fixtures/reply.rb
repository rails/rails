class Reply < ActiveRecord::Base
  named_scope :base
  belongs_to :topic, :include => [:replies]
  belongs_to :developer

  validates_presence_of :content
end
