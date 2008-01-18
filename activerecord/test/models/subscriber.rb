class Subscriber < ActiveRecord::Base
  set_primary_key 'nick'
end

class SpecialSubscriber < Subscriber
end
