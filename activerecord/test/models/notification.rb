class Notification < ActiveRecord::Base
  validates_presence_of :message
end
