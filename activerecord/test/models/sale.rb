class Sale < ActiveRecord::Base
  belongs_to :building, autosave: true
end