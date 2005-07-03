class Subscriber < ActiveRecord::Base
  def self.primary_key
    "nick"
  end
end

class SpecialSubscriber < Subscriber
end