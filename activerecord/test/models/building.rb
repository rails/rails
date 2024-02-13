class Building < ActiveRecord::Base
  has_many :sales, autosave: true
  has_many :expenses, autosave: true
end