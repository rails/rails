# frozen_string_literal: true

class Wheel < ActiveRecord::Base
  belongs_to :wheelable, polymorphic: true, counter_cache: true, touch: :wheels_owned_at
end
