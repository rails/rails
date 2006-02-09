class Reply < ActiveRecord::Base
  belongs_to :topic, :include => [:replies]
  
  validates_presence_of :content
end
