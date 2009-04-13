class Bird < ActiveRecord::Base
  validates_presence_of :name
end