class Subscriber < ActiveRecord::Base
  set_primary_key 'nick'
  has_many :subscriptions
  has_many :books, :through => :subscriptions
end

class SpecialSubscriber < Subscriber
end
