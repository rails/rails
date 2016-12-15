class Entry < ActiveRecord::Base
  belongs_to :order
  validates :title, presence: true
end
