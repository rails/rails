class Listing < ActiveRecord::Base
  belongs_to :building, autosave: true
end