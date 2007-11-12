class Reply < ActiveRecord::Base
  belongs_to :topic, :include => [:replies]
  belongs_to :developer

  validates_presence_of :content
end
