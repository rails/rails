class Wheel < ActiveRecord::Base
  belongs_to :wheelable, polymorphic: true, counter_cache: true
end
