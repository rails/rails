# frozen_string_literal: true

class Starfighter < ActiveRecord::Base
  belongs_to :pilot, counter_cache: true, touch: true
  belongs_to :hangar, counter_cache: true, touch: true, optional: true
end
