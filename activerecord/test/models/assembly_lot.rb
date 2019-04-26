# frozen_string_literal: true

class AssemblyLot < ActiveRecord::Base
  belongs_to :day, counter_cache: true, touch: true
  belongs_to :expiration_day, counter_cache: true, touch: true, optional: true
end
