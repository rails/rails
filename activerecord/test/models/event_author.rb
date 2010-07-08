require 'models/author'
require 'models/event'

class EventAuthor < ActiveRecord::Base
  belongs_to :author
  belongs_to :event
end

