class Star < ActiveRecord::Base
  belongs_to :universe, :counter_cache => true
  has_many :planets
end
