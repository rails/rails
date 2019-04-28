# frozen_string_literal: true

class Pilot < ActiveRecord::Base
  has_one :hangar

  has_many :starfighters
end
