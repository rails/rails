class EventAuthor < ActiveRecord::Base
  belongs_to :author
  belongs_to :event
end

