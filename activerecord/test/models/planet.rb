class Planet < ActiveRecord::Base
  belongs_to :universe, :counter_cache => true
end
